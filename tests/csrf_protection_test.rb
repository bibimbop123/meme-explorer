# Run independently of the app/database: bundle exec ruby tests/csrf_protection_test.rb
require_relative '../lib/middleware/csrf_protection'
require 'stringio'

def check(description)
  raise "FAIL: #{description}" unless yield
  puts "PASS: #{description}"
end

endpoint = ->(env) { [200, {}, [env['rack.input'].read]] }
app = CsrfProtection.new(endpoint)
session = {}
environment = lambda do |method, path = '/like', body = '{}', headers = {}|
  Rack::MockRequest.env_for(path, method: method, input: body,
    'CONTENT_TYPE' => 'application/json').merge('rack.session' => session).merge(headers)
end

check('GET creates a session token') { app.call(environment.call('GET'))[0] == 200 && session['csrf'].size == 64 }
check('missing token is rejected') { app.call(environment.call('POST'))[0] == 403 }
check('forged token is rejected') { app.call(environment.call('POST', '/like', '{}', 'HTTP_X_CSRF_TOKEN' => 'x' * 64))[0] == 403 }
%w[/like /api/save-meme /api/unsave-meme /api/skip-meme /login /signup].each do |path|
  check("valid token accepted for #{path} without consuming JSON") do
    result = app.call(environment.call('POST', path, '{"url":"test"}', 'HTTP_X_CSRF_TOKEN' => session['csrf']))
    result[0] == 200 && result[2].join == '{"url":"test"}'
  end
end
form = environment.call('POST', '/login', "authenticity_token=#{session['csrf']}", 'CONTENT_TYPE' => 'application/x-www-form-urlencoded')
check('native form token accepted') { app.call(form)[0] == 200 }
check('cross-site standard Rack headers cannot bypass missing token') do
  app.call(environment.call('POST', '/like', '{}', 'HTTP_ORIGIN' => 'https://attacker.example', 'HTTP_SEC_FETCH_SITE' => 'cross-site'))[0] == 403
end
check('Stripe signature route reaches its independent verifier') { app.call(environment.call('POST', '/webhooks/stripe'))[0] == 200 }
check('webhook exception is exact, not a path prefix') { app.call(environment.call('POST', '/webhooks/stripe/extra'))[0] == 403 }
check('other session token rejected') do
  app.call(environment.call('POST', '/like', '{}', 'HTTP_X_CSRF_TOKEN' => SecureRandom.hex(32)))[0] == 403
end