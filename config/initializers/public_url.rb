require 'uri'
public_url = ENV.fetch('APP_PUBLIC_URL', 'http://localhost:3000').delete_suffix('/')
uri = URI.parse(public_url)
raise 'APP_PUBLIC_URL must be an absolute HTTP(S) URL without a path' unless %w[http https].include?(uri.scheme) && uri.host && ['', '/'].include?(uri.path) && !uri.query && !uri.fragment && !uri.userinfo
Rails.application.config.x.public_url = public_url
if Rails.env.production? && !ENV['SECRET_KEY_BASE_DUMMY']
  raise 'Set APP_PUBLIC_URL to the public HTTPS origin' unless uri.scheme == 'https'
  Rails.application.config.hosts = [uri.host]
  Rails.application.config.action_cable.allowed_request_origins = [public_url]
end
