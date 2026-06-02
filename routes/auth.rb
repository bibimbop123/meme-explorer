# Authentication Routes
require_relative '../lib/validators'

class AuthRoutes
  def self.register(app)
        # OAuth Reddit Routes
        app.get "/auth/reddit" do
          redirect AuthService.generate_oauth_url(
            settings.reddit_oauth_client_id,
            settings.reddit_redirect_uri
          )
        end

        app.get "/auth/reddit/callback" do
          begin
            puts "🔵 [CALLBACK] Reddit callback hit!"
            $stdout.flush
            
            code = params[:code]
            error = params[:error]
            
            puts "🔵 [CALLBACK] Authorization code: #{code ? 'present' : 'missing'}"
            puts "🔵 [CALLBACK] Error param: #{error}" if error
            $stdout.flush
            
            # User cancelled or error from Reddit
            if error || !code
              session[:error] = "Reddit login was cancelled or failed"
              next redirect("/login")
            end

            puts "🔵 [CALLBACK] Calling AuthService.verify_reddit_oauth..."
            $stdout.flush
            
            result = AuthService.verify_reddit_oauth(
              code,
              settings.reddit_oauth_client_id,
              settings.reddit_oauth_client_secret,
              settings.reddit_redirect_uri
            )

            puts "🔵 [CALLBACK] AuthService result: #{result.inspect}"
            $stdout.flush

            unless result[:success]
              puts "❌ [CALLBACK] OAuth failed: #{result[:error]}"
              $stdout.flush
              
              ErrorHandler::Logger.log(
                StandardError.new("OAuth failed: #{result[:error]}"),
                { provider: "reddit" },
                :error
              ) rescue nil
              
              session[:error] = "Reddit authentication failed. Please try again."
              next redirect("/login")
            end

            user_id = UserService.create_or_find_from_reddit(
              result[:username],
              result[:id],
              nil
            )

            AuthService.store_oauth_token(settings.redis, result[:token]) rescue nil
            session[:user_id] = user_id
            session[:reddit_username] = result[:username]
            session[:reddit_token] = result[:token]

            redirect "/profile", 302
            
          rescue => e
            puts "❌ [CALLBACK] Unexpected error: #{e.message}"
            puts e.backtrace.first(5).join("\n")
            $stdout.flush
            
            ErrorHandler::Logger.log(e, { provider: "reddit" }, :error) rescue nil
            session[:error] = "An unexpected error occurred during Reddit login"
            redirect "/login"
          end
        end

        # Email/Password Routes
        app.get "/login" do
          erb :login
        end

        app.post "/login" do
          content_type :json
          
          begin
            # Whitelist and validate parameters
            safe_params = Validators.whitelist_params(params,
              allowed_keys: [:email, :password],
              optional_keys: []
            )

            # Validate email format (sanitize but don't be too strict on password field itself)
            email = Validators.validate_email(safe_params[:email])
            password = safe_params[:password]
            
            if password.to_s.strip.empty?
              return { success: false, error: "Password required" }.to_json
            end

            # Authenticate using service
            user_id = AuthService.authenticate_email(email, password)
            
            if user_id
              session[:user_id] = user_id
              return { success: true, redirect: "/profile" }.to_json
            else
              ErrorHandler::Logger.log(
                StandardError.new("Failed login attempt"),
                { email: email },
                :warning
              ) rescue nil
              return { success: false, error: "Invalid email or password" }.to_json
            end

          rescue Validators::ValidationError => e
            return { success: false, error: e.message }.to_json
          rescue => e
            ErrorHandler::Logger.log(e, { email: safe_params.to_s }, :error) rescue nil
            return { success: false, error: "Login failed. Please try again." }.to_json
          end
        end

        app.get "/signup" do
          erb :signup
        end

        app.post "/signup" do
          content_type :json
          
          begin
            # Whitelist and validate parameters (username is optional/not used)
            safe_params = Validators.whitelist_params(params,
              allowed_keys: [:email, :password, :password_confirm],
              optional_keys: [:username]
            )

            # Validate each field
            email = Validators.validate_email(safe_params[:email])
            password = Validators.validate_password(safe_params[:password])
            password_confirm = safe_params[:password_confirm]

            # Verify passwords match
            if password != password_confirm
              return { success: false, error: "Passwords do not match" }.to_json
            end

            # Create user with validated data
            user_id = UserService.create_email_user(email, password)
            unless user_id
              return { success: false, error: "Email already in use" }.to_json
            end

            session[:user_id] = user_id
            session[:email] = email
            return { success: true, redirect: "/profile" }.to_json

          rescue Validators::ValidationError => e
            return { success: false, error: e.message }.to_json
          rescue => e
            ErrorHandler::Logger.log(e, { email: safe_params.to_s }, :error) rescue nil
            return { success: false, error: "Registration failed. Please try again." }.to_json
          end
        end

        app.get "/logout" do
          session.clear
          redirect "/"
        end
  end
end
