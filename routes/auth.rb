# Authentication Routes
require_relative '../lib/validators'

module MemeExplorer
  module Routes
    class Auth
      def self.register(app)
        # OAuth Reddit Routes
        app.get "/auth/reddit" do
          redirect AuthService.generate_oauth_url(
            settings.reddit_oauth_client_id,
            settings.reddit_redirect_uri
          )
        end

        app.get "/auth/reddit/callback" do
          code = params[:code]
          halt 400, "No authorization code received" unless code

          result = AuthService.verify_reddit_oauth(
            code,
            settings.reddit_oauth_client_id,
            settings.reddit_oauth_client_secret,
            settings.reddit_redirect_uri
          )

          unless result[:success]
            ErrorHandler::Logger.log(
              StandardError.new("OAuth failed: #{result[:error]}"),
              { provider: "reddit" },
              :error
            )
            halt 400, "OAuth authentication failed: #{result[:error]}"
          end

          user_id = UserService.create_or_find_from_reddit(
            result[:username],
            result[:id],
            nil
          )

          AuthService.store_oauth_token(settings.redis, result[:token])
          session[:user_id] = user_id
          session[:reddit_username] = result[:username]
          session[:reddit_token] = result[:token]

          redirect "/profile", 302
        end

        # Email/Password Routes
        app.get "/login" do
          erb :login
        end

        app.post "/login" do
          begin
            # Whitelist and validate parameters
            safe_params = Validators.whitelist_params(params,
              allowed_keys: [:email, :password],
              optional_keys: []
            )

            # Validate email format (sanitize but don't be too strict on password field itself)
            email = Validators.validate_email(safe_params[:email])
            password = safe_params[:password]
            
            halt 422, { success: false, error: "Password required" }.to_json if password.to_s.strip.empty?

            # Authenticate using service
            user_id = AuthService.authenticate_email(email, password)
            
            if user_id
              session[:user_id] = user_id
              redirect "/profile"
            else
              ErrorHandler::Logger.log(
                StandardError.new("Failed login attempt"),
                { email: email },
                :warning
              )
              halt 401, { success: false, error: "Invalid email or password" }.to_json
            end

          rescue Validators::ValidationError => e
            halt 422, { success: false, error: e.message }.to_json
          end
        end

        app.get "/signup" do
          erb :signup
        end

        app.post "/signup" do
          begin
            # Whitelist and validate parameters
            safe_params = Validators.whitelist_params(params,
              allowed_keys: [:email, :username, :password, :password_confirm],
              optional_keys: []
            )

            # Validate each field
            email = Validators.validate_email(safe_params[:email])
            username = Validators.validate_username(safe_params[:username])
            password = Validators.validate_password(safe_params[:password])
            password_confirm = safe_params[:password_confirm]

            # Verify passwords match
            halt 422, { success: false, error: "Passwords do not match" }.to_json if password != password_confirm

            # Create user with validated data
            user_id = UserService.create_email_user(email, password)
            halt 409, { success: false, error: "Email already in use" }.to_json unless user_id

            session[:user_id] = user_id
            session[:email] = email
            redirect "/profile"

          rescue Validators::ValidationError => e
            halt 422, { success: false, error: e.message }.to_json
          end
        end

        app.get "/logout" do
          session.clear
          redirect "/"
        end
      end
    end
  end
end
