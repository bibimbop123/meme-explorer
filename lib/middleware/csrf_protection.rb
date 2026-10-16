# frozen_string_literal: true

require 'rack'
require 'securerandom'
require 'json'

# Session middleware must wrap this middleware. JSON bodies are never consumed.
class CsrfProtection
  SAFE_METHODS = %w[GET HEAD OPTIONS].freeze
  TOKEN_KEY = 'csrf'

  def initialize(app)
    @app = app
  end

  def call(env)
    # Stripe authenticates the raw payload with its own signature in the route.
    return @app.call(env) if env['REQUEST_METHOD'] == 'POST' && env['PATH_INFO'] == '/webhooks/stripe'

    session = env.fetch('rack.session')
    session[TOKEN_KEY] ||= SecureRandom.hex(32)
    return @app.call(env) if SAFE_METHODS.include?(env['REQUEST_METHOD'])

    request = Rack::Request.new(env)
    supplied = env['HTTP_X_CSRF_TOKEN']
    supplied ||= request.POST['authenticity_token'] if request.form_data?
    expected = session[TOKEN_KEY]
    if supplied.is_a?(String) && supplied.bytesize == expected.bytesize &&
        Rack::Utils.secure_compare(expected, supplied)
      return @app.call(env)
    end

    [403, { 'content-type' => 'application/json', 'cache-control' => 'no-store' },
      [JSON.generate(error: 'Your security token is missing or expired. Reload the page and try again.')]]
  end
end