require 'connection_pool'
require 'digest'
require 'redis'

class RequestRateLimiter
  LUA_INCREMENT = <<~LUA.freeze
    local current = redis.call('INCR', KEYS[1])
    if current == 1 then
      redis.call('EXPIRE', KEYS[1], ARGV[1])
    end
    return { current, redis.call('TTL', KEYS[1]) }
  LUA

  DEFAULTS = {
    login_account_10m: 10,
    login_ip_10m: 100,
    orders_customer_10m: 15,
    orders_customer_1h: 60,
    orders_table_10m: 40,
    orders_table_1h: 120,
    orders_ip_10m: 600,
    calls_customer_10m: 5,
    calls_table_10m: 10,
    calls_ip_10m: 300
  }.freeze

  ENVIRONMENT_KEYS = DEFAULTS.keys.to_h do |name|
    [name, "RATE_LIMIT_#{name.to_s.upcase}"]
  end.freeze

  class RedisCounter
    def initialize
      size = [ENV.fetch('RAILS_MAX_THREADS', 5).to_i, 1].max
      @pool = ConnectionPool.new(size: size, timeout: 0.5) do
        Redis.new(
          url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
          connect_timeout: 0.25,
          read_timeout: 0.25,
          write_timeout: 0.25,
          reconnect_attempts: 1
        )
      end
    end

    def increment(key, period)
      @pool.with do |redis|
        count, ttl = redis.eval(LUA_INCREMENT, keys: [key], argv: [period])
        [count.to_i, ttl.to_i]
      end
    end

    def delete(key)
      @pool.with { |redis| redis.del(key) }
    end
  end

  def initialize(app, counter: nil)
    @app = app
    @counter = counter
  end

  def call(environment)
    request = ActionDispatch::Request.new(environment)
    buckets = buckets_for(request)
    return @app.call(environment) if buckets.empty?

    begin
      exceeded = consume(buckets)
    rescue Redis::BaseError, ConnectionPool::TimeoutError => error
      return fail_open(environment, error)
    end
    return rate_limited_response(exceeded) if exceeded

    response = @app.call(environment)
    reset_successful_login(request, buckets, response)
    response
  end

  private

  def counter
    @counter ||= RedisCounter.new
  end

  def buckets_for(request)
    return [] unless request.post?

    if request.path == '/login'
      identifier = request.params['identifier'].presence || request.params['email'].presence || 'missing'
      return [
        bucket(:login_account_10m, 10.minutes, request.ip, identifier.to_s.downcase.strip),
        bucket(:login_ip_10m, 10.minutes, request.ip)
      ]
    end

    match = request.path.match(%r{\A/tables/([^/]+)/orders\z})
    if match
      table_token = match[1]
      customer = request.session[:customer_token].presence || "ip:#{request.ip}"
      return [
        bucket(:orders_customer_10m, 10.minutes, table_token, customer),
        bucket(:orders_customer_1h, 1.hour, table_token, customer),
        bucket(:orders_table_10m, 10.minutes, table_token),
        bucket(:orders_table_1h, 1.hour, table_token),
        bucket(:orders_ip_10m, 10.minutes, request.ip)
      ]
    end

    match = request.path.match(%r{\A/tables/([^/]+)/service_calls\z})
    return [] unless match

    table_token = match[1]
    customer = request.session[:customer_token].presence || "ip:#{request.ip}"
    [
      bucket(:calls_customer_10m, 10.minutes, table_token, customer),
      bucket(:calls_table_10m, 10.minutes, table_token),
      bucket(:calls_ip_10m, 10.minutes, request.ip)
    ]
  end

  def bucket(name, period, *identity)
    raw_identity = identity.map(&:to_s).join("\0")
    digest = Digest::SHA256.hexdigest(raw_identity)
    limit = ENV.fetch(ENVIRONMENT_KEYS.fetch(name), DEFAULTS.fetch(name)).to_i
    limit = DEFAULTS.fetch(name) unless limit.positive?
    {
      name: name,
      key: "qr_table_ordering:rate:v1:#{name}:#{digest}",
      limit: limit,
      period: period.to_i
    }
  end

  def consume(buckets)
    buckets.each do |bucket|
      count, ttl = counter.increment(bucket[:key], bucket[:period])
      next if count <= bucket[:limit]

      return bucket.merge(retry_after: ttl.positive? ? ttl : bucket[:period])
    end
    nil
  end

  def reset_successful_login(request, buckets, response)
    return unless request.path == '/login' && response.first.in?([302, 303])

    account_bucket = buckets.find { |bucket| bucket[:name] == :login_account_10m }
    counter.delete(account_bucket[:key]) if account_bucket
  rescue Redis::BaseError, ConnectionPool::TimeoutError => error
    Rails.logger.error("Rate limiter reset unavailable: #{error.class}")
  end

  def fail_open(environment, error)
    Rails.logger.error("Rate limiter unavailable: #{error.class}")
    @app.call(environment)
  end

  def rate_limited_response(bucket)
    body = 'Demasiadas tentativas. Aguarde um pouco antes de tentar novamente.'
    Rails.logger.warn("Rate limit exceeded: #{bucket[:name]}")
    [
      429,
      {
        'Content-Type' => 'text/plain; charset=utf-8',
        'Content-Length' => body.bytesize.to_s,
        'Cache-Control' => 'no-store',
        'Retry-After' => bucket[:retry_after].to_s,
        'X-RateLimit-Rule' => bucket[:name].to_s
      },
      [body]
    ]
  end
end
