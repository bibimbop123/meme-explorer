# Authentication Routes
require_relative '../lib/validators'

class AuthRoutes
  def self.register(app)
        # OAuth Reddit Routes
        app.get "/auth/reddit" do
          # ✅ SECURITY FIX: Generate and store OAuth state parameter
          state = SecureRandom.hex(32)
          session[:oauth_state] = state
          session[:oauth_state_timestamp] = Time.now.to_i
          
          redirect AuthService.generate_oauth_url(
            settings.reddit_oauth_client_id,
            settings.reddit_redirect_uri,
            state
          )
        end

        app.get "/auth/reddit/callback" do
          begin
            AppLogger.info("Reddit OAuth callback received",
              code_present: !params[:code].nil?,
              state_present: !params[:state].nil?,
              ip: request.ip
            )
            
            code = params[:code]
            error = params[:error]
            state = params[:state]
            
            # User cancelled or error from Reddit
            if error || !code
              session[:error] = "Reddit login was cancelled or failed"
              next redirect("/login")
            end
            
            # ✅ SECURITY FIX: Validate OAuth state parameter
            unless state && session[:oauth_state] && state == session[:oauth_state]
              AppLogger.warn("OAuth state validation failed",
                state_present: !state.nil?,
                session_state_present: !session[:oauth_state].nil?,
                match: state == session[:oauth_state],
                ip: request.ip
              )
              session[:error] = "Invalid OAuth state - possible CSRF attack"
              next redirect("/login")
            end
            
            # ✅ SECURITY FIX: Check state timestamp (expire after 10 minutes)
            if session[:oauth_state_timestamp]
              elapsed = Time.now.to_i - session[:oauth_state_timestamp].to_i
              if elapsed > 600
                AppLogger.warn("OAuth state expired",
                  elapsed_seconds: elapsed,
                  ip: request.ip
                )
                session[:error] = "OAuth session expired. Please try again."
                next redirect("/login")
              end
            end
            
            # Clear state after validation
            session.delete(:oauth_state)
            session.delete(:oauth_state_timestamp)

            AppLogger.info("Exchanging OAuth code for token", ip: request.ip)
            
            result = AuthService.verify_reddit_oauth(
              code,
              settings.reddit_oauth_client_id,
              settings.reddit_oauth_client_secret,
              settings.reddit_redirect_uri
            )

            unless result[:success]
              AppLogger.error("Reddit OAuth token exchange failed",
                error: result[:error],
                ip: request.ip
              )
              
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

            # Store token in Redis (non-critical, degrades gracefully if Redis unavailable)
            AuthService.store_oauth_token(settings.redis, result[:token])
            
            # Set session data (session fixation prevented by Rack::Session)
            session[:user_id] = user_id
            session[:reddit_username] = result[:username]
            session[:login_timestamp] = Time.now.to_i
            session[:login_ip] = request.ip

            AppLogger.info("Reddit OAuth successful",
              username: result[:username],
              user_id: user_id,
              ip: request.ip,
              session_regenerated: true
            )
            
            redirect "/profile", 302
            
          rescue => e
            AppLogger.error("Reddit OAuth callback error",
              error_class: e.class.name,
              error_message: e.message,
              backtrace: e.backtrace.first(5),
              ip: request.ip
            )
            
            ErrorHandler::Logger.log(e, { 
              provider: "reddit",
              code_present: !code.nil?,
              error_param: error,
              callback_url: request.url
            }, :error)
            
            session[:error] = "An unexpected error occurred during Reddit login. Please try again."
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

            # Handle both symbol and string keys from FormData
            email_param = safe_params[:email] || safe_params['email']
            password_param = safe_params[:password] || safe_params['password']
            
            # Validate email format (sanitize but don't be too strict on password field itself)
            email = Validators.validate_email(email_param)
            password = password_param
            
            if password.to_s.strip.empty?
              return { success: false, error: "Password required" }.to_json
            end

            # ✅ SECURITY FIX: Check if account is locked due to failed attempts
            redis = settings.redis rescue nil
            if AuthService.account_locked?(email, redis)
              remaining = AuthService.lockout_time_remaining(email, redis)
              minutes = (remaining / 60.0).ceil
              
              AppLogger.warn("Login attempt on locked account",
                email: email,
                ip: request.ip,
                remaining_seconds: remaining
              )
              
              return { 
                success: false, 
                error: "Account temporarily locked due to too many failed attempts. Try again in #{minutes} minute#{minutes != 1 ? 's' : ''}.",
                locked: true,
                retry_after: remaining
              }.to_json
            end

            # Authenticate using service
            user_id = AuthService.authenticate_email(email, password)
            
            if user_id
              # ✅ SECURITY FIX: Clear failed login attempts on successful login
              AuthService.clear_failed_logins(email, redis)
              
              # Set session data (session fixation prevented by Rack::Session)
              session[:user_id] = user_id
              session[:login_timestamp] = Time.now.to_i
              session[:login_ip] = request.ip
              
              AppLogger.info("User login successful",
                user_id: user_id,
                email: email,
                ip: request.ip
              )
              
              return { success: true, redirect: "/profile" }.to_json
            else
              # ✅ SECURITY FIX: Record failed login attempt
              AuthService.record_failed_login(email, redis)
              remaining_attempts = AuthService.remaining_attempts(email, redis)
              
              ErrorHandler::Logger.log(
                StandardError.new("Failed login attempt"),
                { 
                  email: email,
                  remaining_attempts: remaining_attempts,
                  ip: request.ip
                },
                :warning
              ) rescue nil
              
              error_msg = "Invalid email or password"
              if remaining_attempts <= 2 && remaining_attempts > 0
                error_msg += ". #{remaining_attempts} attempt#{remaining_attempts != 1 ? 's' : ''} remaining before temporary lockout."
              end
              
              return { 
                success: false, 
                error: error_msg,
                remaining_attempts: remaining_attempts
              }.to_json
            end

          rescue Validators::ValidationError => e
            return { success: false, error: e.message }.to_json
          rescue => e
            ErrorHandler::Logger.log(e, { params: safe_params.to_s }, :error)
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

            # Handle both symbol and string keys from FormData
            email_param = safe_params[:email] || safe_params['email']
            password_param = safe_params[:password] || safe_params['password']
            password_confirm_param = safe_params[:password_confirm] || safe_params['password_confirm']

            # Validate each field
            email = Validators.validate_email(email_param)
            password = Validators.validate_password(password_param)
            password_confirm = password_confirm_param

            # Verify passwords match
            if password != password_confirm
              return { success: false, error: "Passwords do not match" }.to_json
            end

            # Create user with validated data
            user_id = UserService.create_email_user(email, password)
            unless user_id
              return { success: false, error: "Email already in use" }.to_json
            end

            # Set session data (session fixation prevented by Rack::Session)
            session[:user_id] = user_id
            session[:email] = email
            session[:login_timestamp] = Time.now.to_i
            session[:login_ip] = request.ip
            
            AppLogger.info("User signup successful",
              user_id: user_id,
              email: email,
              ip: request.ip
            )
            
            return { success: true, redirect: "/profile" }.to_json

          rescue Validators::ValidationError => e
            return { success: false, error: e.message }.to_json
          rescue => e
            ErrorHandler::Logger.log(e, { params: safe_params.to_s }, :error)
            return { success: false, error: "Registration failed. Please try again." }.to_json
          end
        end

        app.get "/logout" do
          session.clear
          redirect "/"
        end
  end
end
