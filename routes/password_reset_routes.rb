# Password reset routes - provider-agnostic account recovery.
# See docs/REMAINING_WORK_EXECUTION_ROADMAP.md Stage 5 for the threat model:
# non-enumerating responses, hashed single-use expiring tokens, atomic
# consumption, bounded request rates, no raw tokens in logs.
require_relative '../lib/services/password_reset_service'
require_relative '../lib/services/mailer'

module Routes
  module PasswordResetRoutes
    GENERIC_FORGOT_MESSAGE = 'If an account exists for that email, a reset link is on its way.'

    def self.registered(app)
      app.get '/password/forgot' do
        headers 'Cache-Control' => 'no-store, private'
        @mailer_configured = Mailer.configured?
        erb :password_forgot
      end

      app.post '/password/forgot' do
        headers 'Cache-Control' => 'no-store, private'
        content_type :json

        unless Mailer.configured?
          halt 503, { success: false, error: 'Password reset is temporarily unavailable. Please try again later.' }.to_json
        end

        begin
          email = Validators.validate_email(params[:email])
        rescue Validators::ValidationError => e
          halt 400, { success: false, error: e.message }.to_json
        end

        PasswordResetService.request_reset(email: email, ip: request.ip)
        # Identical response whether or not the account exists / mail sent.
        { success: true, message: GENERIC_FORGOT_MESSAGE }.to_json
      end

      app.get '/password/reset/:token' do
        headers 'Cache-Control' => 'no-store, private'
        @token = params[:token]
        @token_state = PasswordResetService.token_state(@token)
        erb :password_reset
      end

      app.post '/password/reset' do
        headers 'Cache-Control' => 'no-store, private'
        content_type :json

        token = params[:token].to_s
        password = params[:password].to_s
        confirm = params[:password_confirm].to_s

        halt 400, { success: false, error: 'Reset token required' }.to_json if token.empty?
        halt 400, { success: false, error: 'Passwords do not match' }.to_json if password != confirm

        begin
          Validators.validate_password(password)
        rescue Validators::ValidationError => e
          halt 400, { success: false, error: e.message }.to_json
        end

        result = PasswordResetService.consume(token: token, new_password: password)
        if result[:success]
          AppLogger.info('[PASSWORD RESET] password updated', user_id: result[:user_id])
          { success: true, redirect: '/login?reset=1' }.to_json
        elsif result[:reason] == :invalid_token
          halt 400, { success: false, error: 'This reset link is invalid or has already been used. Request a new one.' }.to_json
        else
          halt 503, { success: false, error: 'Password reset is temporarily unavailable. Please try again.' }.to_json
        end
      end
    end
  end
end
