require 'test_helper'

class RequestRateLimiterTest < ActiveSupport::TestCase
  class MemoryCounter
    attr_reader :counts

    def initialize(error: nil)
      @counts = Hash.new(0)
      @error = error
    end

    def increment(key, period)
      raise @error if @error

      @counts[key] += 1
      [@counts[key], period]
    end

    def delete(key)
      @counts.delete(key)
    end
  end

  setup do
    @application = ->(_environment) { [204, {}, []] }
    @counter = MemoryCounter.new
    @middleware = RequestRateLimiter.new(@application, counter: @counter)
  end

  test 'ten products in one order count as one request' do
    response = request(
      '/tables/table-a/orders',
      session: { customer_token: 'customer-a' },
      params: { quantity: '10' }
    )

    assert_equal 204, response.first
    assert_equal 5, @counter.counts.values.sum
  end

  test 'customer can submit fifteen orders and the next request is limited' do
    15.times do
      assert_equal 204, request('/tables/table-a/orders', session: { customer_token: 'customer-a' }).first
    end

    status, headers, body = request('/tables/table-a/orders', session: { customer_token: 'customer-a' })

    assert_equal 429, status
    assert_equal '600', headers['Retry-After']
    assert_equal 'orders_customer_10m', headers['X-RateLimit-Rule']
    assert_includes body.join, 'Demasiadas tentativas'
  end

  test 'table aggregate is limited without mixing different tables' do
    4.times do |customer|
      10.times do
        assert_equal 204, request('/tables/table-a/orders', session: { customer_token: "customer-#{customer}" }).first
      end
    end

    assert_equal 429, request('/tables/table-a/orders', session: { customer_token: 'customer-extra' }).first
    assert_equal 204, request('/tables/table-b/orders', session: { customer_token: 'customer-extra' }).first
  end

  test 'shared cafe IP allows simultaneous orders at thirty tables' do
    30.times do |number|
      status, = request(
        "/tables/table-#{number}/orders",
        ip: '203.0.113.10',
        session: { customer_token: "customer-#{number}" }
      )
      assert_equal 204, status
    end
  end

  test 'login limit is isolated by account on the same IP' do
    10.times do
      assert_equal 204, request('/login', params: { email: 'one@example.com' }).first
    end

    assert_equal 429, request('/login', params: { email: 'one@example.com' }).first
    assert_equal 204, request('/login', params: { email: 'two@example.com' }).first
  end

  test 'successful login clears failures for that account' do
    9.times do
      assert_equal 204, request('/login', params: { email: 'one@example.com' }).first
    end

    successful = ->(_environment) { [303, { 'Location' => '/staff/orders' }, []] }
    successful_middleware = RequestRateLimiter.new(successful, counter: @counter)
    assert_equal 303, request('/login', params: { email: 'one@example.com' }, middleware: successful_middleware).first

    assert_equal 204, request('/login', params: { email: 'one@example.com' }).first
  end

  test 'service calls are limited per customer and table' do
    5.times do
      assert_equal 204, request('/tables/table-a/service_calls', session: { customer_token: 'customer-a' }).first
    end

    status, headers, = request('/tables/table-a/service_calls', session: { customer_token: 'customer-a' })
    assert_equal 429, status
    assert_equal 'calls_customer_10m', headers['X-RateLimit-Rule']
  end

  test 'Redis outage fails open so venue operation continues' do
    error = Redis::CannotConnectError.new('offline')
    middleware = RequestRateLimiter.new(@application, counter: MemoryCounter.new(error: error))

    assert_equal 204, request('/tables/table-a/orders', middleware: middleware).first
  end

  private

  def request(path, ip: '198.51.100.20', session: {}, params: {}, middleware: @middleware)
    input = Rack::Utils.build_nested_query(params)
    environment = Rack::MockRequest.env_for(
      path,
      method: 'POST',
      input: input,
      'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
      'REMOTE_ADDR' => ip
    )
    environment['rack.session'] = session
    middleware.call(environment)
  end
end
