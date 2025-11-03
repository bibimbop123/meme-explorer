# Authentication Routes
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
          email = params[:email]
          password = params[:password]

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
            halt 401, "Invalid email or password"
          end
        end

        app.get "/signup" do
          erb :signup
        end

        app.post "/signup" do
          email = params[:email]
          password = params[:password]
          password_confirm = params[:password_confirm]

          halt 400, "Passwords do not match" if password != password_confirm
          halt 400, "Email and password required" if email.to_s.strip.empty? || password.to_s.strip.empty?

          user_id = UserService.create_email_user(email, password)
          halt 400, "Email already in use" unless user_id

          session[:user_id] = user_id
          session[:email] = email
          redirect "/profile"
        end

        app.get "/logout" do
          session.clear
          redirect "/"
        end
      end
    end
  end
end
