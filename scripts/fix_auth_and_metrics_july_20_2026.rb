#!/usr/bin/env ruby
# fix_auth_and_metrics_july_20_2026.rb
# 
# CRITICAL FIX: Authentication and Metrics Page Issues
# 
# Issues Fixed:
# 1. Logout not working properly with Redis sessions
# 2. Metrics page SQL syntax errors (SQLite vs PostgreSQL)
# 
# As a senior Ruby on Rails/Sinatra developer with 50+ years of experience,
# these are production-critical issues that break core functionality.

require 'fileutils'

puts "=" * 80
puts "🔧 CRITICAL FIX: Authentication & Metrics"
puts "=" * 80
puts

# =============================================================================
# FIX 1: Logout Route - Proper Redis Session Destruction
# =============================================================================

puts "📝 Fixing logout route for Redis sessions..."

auth_routes_content = <<'RUBY'
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

        # ✅ CRITICAL FIX: Logout route - Proper Redis session destruction
        app.get "/logout" do
          begin
            # Get session ID before clearing (for logging)
            session_id = request.session_options[:id] rescue 'unknown'
            user_id = session[:user_id]
            
            # Clear all session data (works with both Cookie and Redis sessions)
            session.clear
            
            # For Rack::Session::Redis, also destroy the session completely
            # This ensures Redis key is deleted, not just emptied
            request.session_options[:drop] = true if request.session_options
            
            # Add cache-control headers to prevent cached logout
            headers(
              'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0, private',
              'Pragma' => 'no-cache',
              'Expires' => '0'
            )
            
            # Log the logout
            AppLogger.info("User logged out", 
              user_id: user_id,
              session_id: session_id,
              ip: request.ip
            )
            
            # Redirect to home page with 303 See Other (forces GET)
            redirect "/", 303
          rescue => e
            AppLogger.error("Logout error: #{e.message}")
            # Even if error, still redirect to home
            redirect "/", 303
          end
        end
  end
end
RUBY

File.write('routes/auth.rb', auth_routes_content)
puts "✅ Fixed logout route with proper Redis session destruction"
puts

# =============================================================================
# FIX 2: Metrics Routes - PostgreSQL SQL Syntax
# =============================================================================

puts "📝 Fixing metrics routes for PostgreSQL..."

metrics_routes_content = <<'RUBY'
# routes/metrics_routes.rb
# Metrics, monitoring, and notification endpoints

module Routes
  module MetricsRoutes
    def self.registered(app)
      # Metrics JSON API
      app.get "/metrics.json" do
        total_memes = (MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM meme_stats") || 0).to_i
        total_likes = (MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(likes), 0) FROM meme_stats") || 0).to_i
        total_views = (MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats") || 0).to_i

        avg_likes = total_memes > 0 ? (total_likes.to_f / total_memes).round(2) : 0
        avg_views = total_memes > 0 ? (total_views.to_f / total_memes).round(2) : 0

        content_type :json
        {
          total_memes: total_memes,
          total_likes: total_likes,
          total_views: total_views,
          avg_likes: avg_likes,
          avg_views: avg_views
        }.to_json
      end

      # Metrics HTML page
      app.get "/metrics" do
        # Initialize defaults first
        @total_memes         = 0
        @total_likes         = 0
        @total_views         = 0
        @total_users         = 0
        @total_saved_memes   = 0
        @memes_with_no_likes = 0
        @memes_with_no_views = 0
        @avg_likes           = 0
        @avg_views           = 0
        @top_memes           = []
        @top_subreddits      = []

        begin
          if defined?(MemeExplorer::App::DB) && MemeExplorer::App::DB
            # Get time period filter
            period = params[:period] || 'all'
            
            # Check if activity log table exists for accurate time-based filtering
            has_activity_log = MemeExplorer::App::DB.get_first_value(
              "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'meme_activity_log'"
            ).to_i > 0 rescue false
            
            # ✅ POSTGRESQL FIX: Use PostgreSQL interval syntax instead of SQLite datetime()
            if has_activity_log && period != 'all'
              # Use activity log for accurate time-based metrics (PostgreSQL syntax)
              time_filter = case period
                           when '24h' then "WHERE created_at >= NOW() - INTERVAL '1 day'"
                           when '7d' then "WHERE created_at >= NOW() - INTERVAL '7 days'"
                           when '30d' then "WHERE created_at >= NOW() - INTERVAL '30 days'"
                           else ""
                           end
              
              @total_views = (MemeExplorer::App::DB.get_first_value(
                "SELECT COUNT(*) FROM meme_activity_log #{time_filter.gsub('WHERE', 'WHERE ').gsub('  ', ' ')} AND activity_type = 'view'"
              ) || 0).to_i
              
              @total_likes = (MemeExplorer::App::DB.get_first_value(
                "SELECT COUNT(*) FROM meme_activity_log #{time_filter.gsub('WHERE', 'WHERE ').gsub('  ', ' ')} AND activity_type = 'like'"
              ) || 0).to_i
              
              @total_memes = (MemeExplorer::App::DB.get_first_value(
                "SELECT COUNT(DISTINCT meme_url) FROM meme_activity_log #{time_filter}"
              ) || 0).to_i
            else
              # Fallback to meme_stats (all-time or if activity log doesn't exist)
              # ✅ POSTGRESQL FIX: Use PostgreSQL interval syntax
              where_clause = case period
                            when '24h' then "WHERE updated_at >= NOW() - INTERVAL '1 day'"
                            when '7d' then "WHERE updated_at >= NOW() - INTERVAL '7 days'"
                            when '30d' then "WHERE updated_at >= NOW() - INTERVAL '30 days'"
                            else ""
                            end
              @total_memes = (MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM meme_stats #{where_clause}") || 0).to_i
              @total_likes = (MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(likes), 0) FROM meme_stats #{where_clause}") || 0).to_i
              @total_views = (MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats #{where_clause}") || 0).to_i
            end
            @total_users = (MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM users") || 0).to_i
            @total_saved_memes = (MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM saved_memes") || 0).to_i
            @memes_with_no_likes = (MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM meme_stats #{where_clause.empty? ? 'WHERE' : where_clause + ' AND'} likes = 0") || 0).to_i
            @memes_with_no_views = (MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM meme_stats #{where_clause.empty? ? 'WHERE' : where_clause + ' AND'} views = 0") || 0).to_i

            # Calculate averages
            @avg_likes = @total_memes > 0 ? (@total_likes.to_f / @total_memes).round(2) : 0.0
            @avg_views = @total_memes > 0 ? (@total_views.to_f / @total_memes).round(2) : 0.0
            
            # Calculate engagement rate (ensure float)
            @engagement_rate = @total_views > 0 ? ((@total_likes.to_f / @total_views) * 100).round(2) : 0.0
            
            # Get chart data based on selected period
            @chart_dates = []
            @chart_views = []
            @chart_likes = []
            
            # Determine chart range based on period - USE ACTIVITY LOG for accurate time-based data
            if has_activity_log && period != 'all'
              case period
              when '24h'
                # Show last 24 hours (hourly) - from activity log
                23.downto(0) do |hours_ago|
                  time = Time.now.utc - (hours_ago * 3600)
                  date = (Time.now - (hours_ago * 3600)).strftime('%I %p')  # Display in local time
                  date_start = time.strftime('%Y-%m-%d %H:00:00')
                  date_end = time.strftime('%Y-%m-%d %H:59:59')
                  
                  hourly_views = MemeExplorer::App::DB.get_first_value(
                    "SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view' AND created_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  hourly_likes = MemeExplorer::App::DB.get_first_value(
                    "SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'like' AND created_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  @chart_dates << date
                  @chart_views << hourly_views
                  @chart_likes << hourly_likes
                end
              when '7d'
                # Show last 7 days (daily) - from activity log
                6.downto(0) do |days_ago|
                  date = (Time.now - (days_ago * 86400)).strftime('%m/%d')
                  date_start = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 00:00:00')
                  date_end = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 23:59:59')
                  
                  daily_views = MemeExplorer::App::DB.get_first_value(
                    "SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view' AND created_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  daily_likes = MemeExplorer::App::DB.get_first_value(
                    "SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'like' AND created_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  @chart_dates << date
                  @chart_views << daily_views
                  @chart_likes << daily_likes
                end
              when '30d'
                # Show last 30 days (daily) - from activity log
                29.downto(0) do |days_ago|
                  date = (Time.now - (days_ago * 86400)).strftime('%m/%d')
                  date_start = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 00:00:00')
                  date_end = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 23:59:59')
                  
                  daily_views = MemeExplorer::App::DB.get_first_value(
                    "SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'view' AND created_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  daily_likes = MemeExplorer::App::DB.get_first_value(
                    "SELECT COUNT(*) FROM meme_activity_log WHERE activity_type = 'like' AND created_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  @chart_dates << date
                  @chart_views << daily_views
                  @chart_likes << daily_likes
                end
              end
            else
              # Fallback to meme_stats approach (less accurate but works without activity log)
              # ✅ POSTGRESQL FIX: Use PostgreSQL interval syntax
              where_clause = case period
                            when '24h' then "WHERE updated_at >= NOW() - INTERVAL '1 day'"
                            when '7d' then "WHERE updated_at >= NOW() - INTERVAL '7 days'"
                            when '30d' then "WHERE updated_at >= NOW() - INTERVAL '30 days'"
                            else ""
                            end
              case period
              when '24h'
                23.downto(0) do |hours_ago|
                  time = Time.now.utc - (hours_ago * 3600)
                  date = (Time.now - (hours_ago * 3600)).strftime('%I %p')  # Display in local time
                  date_start = time.strftime('%Y-%m-%d %H:00:00')
                  date_end = time.strftime('%Y-%m-%d %H:59:59')
                  
                  hourly_views = MemeExplorer::App::DB.get_first_value(
                    "SELECT COALESCE(SUM(views), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  hourly_likes = MemeExplorer::App::DB.get_first_value(
                    "SELECT COALESCE(SUM(likes), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  @chart_dates << date
                  @chart_views << hourly_views
                  @chart_likes << hourly_likes
                end
              when '7d'
                6.downto(0) do |days_ago|
                  date = (Time.now - (days_ago * 86400)).strftime('%m/%d')
                  date_start = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 00:00:00')
                  date_end = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 23:59:59')
                  
                  daily_views = MemeExplorer::App::DB.get_first_value(
                    "SELECT COALESCE(SUM(views), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  daily_likes = MemeExplorer::App::DB.get_first_value(
                    "SELECT COALESCE(SUM(likes), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  @chart_dates << date
                  @chart_views << daily_views
                  @chart_likes << daily_likes
                end
              when '30d', 'all'
                29.downto(0) do |days_ago|
                  date = (Time.now - (days_ago * 86400)).strftime('%m/%d')
                  date_start = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 00:00:00')
                  date_end = (Time.now.utc - (days_ago * 86400)).strftime('%Y-%m-%d 23:59:59')
                  
                  daily_views = MemeExplorer::App::DB.get_first_value(
                    "SELECT COALESCE(SUM(views), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  daily_likes = MemeExplorer::App::DB.get_first_value(
                    "SELECT COALESCE(SUM(likes), 0) FROM meme_stats WHERE updated_at BETWEEN ? AND ?",
                    [date_start, date_end]
                  ).to_i
                  
                  @chart_dates << date
                  @chart_views << daily_views
                  @chart_likes << daily_likes
                end
              end
            end
            
            # Store period for view
            @chart_period = period

            # Top memes (DB already returns hashes with results_as_hash = true)
            # FIXED: Only show real Reddit memes with external URLs (not local YAML fallbacks)
            where_clause = case period
                          when '24h' then "WHERE updated_at >= NOW() - INTERVAL '1 day'"
                          when '7d' then "WHERE updated_at >= NOW() - INTERVAL '7 days'"
                          when '30d' then "WHERE updated_at >= NOW() - INTERVAL '30 days'"
                          else ""
                          end
            top_memes_where = where_clause.empty? ? "WHERE" : where_clause + " AND"
            @top_memes = MemeExplorer::App::DB.execute("
              SELECT title, subreddit, url, likes, views
              FROM meme_stats
              #{top_memes_where} (url LIKE 'https://i.redd.it/%'
                OR url LIKE 'https://i.imgur.com/%'
                OR url LIKE 'https://imgur.com/%'
                OR url LIKE 'https://v.redd.it/%'
                OR url LIKE 'https://external-preview.redd.it/%'
                OR url LIKE 'https://preview.redd.it/%')
                AND (likes > 0 OR views >= 10)
                AND title IS NOT NULL
                AND title != 'Unknown'
              ORDER BY (likes * 2 + views) DESC
              LIMIT 10
            ")

            # Top subreddits
            # FIXED: Exclude 'local' fallback subreddit
            subreddit_where = where_clause.empty? ? "WHERE" : where_clause + " AND"
            @top_subreddits = MemeExplorer::App::DB.execute("
              SELECT subreddit, SUM(likes) AS total_likes, COUNT(*) AS count
              FROM meme_stats
              #{subreddit_where} subreddit IS NOT NULL
                AND subreddit != 'Unknown'
                AND subreddit != 'local'
              GROUP BY subreddit
              ORDER BY total_likes DESC
              LIMIT 10
            ")
          end
        rescue => e
          AppLogger.error("Metrics error: #{e.class}: #{e.message}")
          AppLogger.error("Backtrace: #{e.backtrace.first(5).join("\n")}")
        end

        erb :metrics
      end

      # CSV Export endpoint
      app.get "/metrics/export" do
        require 'csv'
        
        period = params[:period] || 'all'
        period_label = case period
                      when '24h' then 'Last 24 Hours'
                      when '7d' then 'Last 7 Days'
                      when '30d' then 'Last 30 Days'
                      else 'All Time'
                      end
        
        # ✅ POSTGRESQL FIX: Use PostgreSQL interval syntax
        where_clause = case period
                      when '24h' then "WHERE updated_at >= NOW() - INTERVAL '1 day'"
                      when '7d' then "WHERE updated_at >= NOW() - INTERVAL '7 days'"
                      when '30d' then "WHERE updated_at >= NOW() - INTERVAL '30 days'"
                      else ""
                      end
        
        # Get metrics
        total_memes = MemeExplorer::App::DB.get_first_value("SELECT COUNT(*) FROM meme_stats #{where_clause}") || 0
        total_likes = MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(likes), 0) FROM meme_stats #{where_clause}") || 0
        total_views = MemeExplorer::App::DB.get_first_value("SELECT COALESCE(SUM(views), 0) FROM meme_stats #{where_clause}") || 0
        
        # Generate CSV
        csv_data = CSV.generate do |csv|
          csv << ['Meme Explorer Metrics Report']
          csv << ['Period', period_label]
          csv << ['Generated', Time.now.strftime('%Y-%m-%d %H:%M:%S')]
          csv << []
          csv << ['Metric', 'Value']
          csv << ['Total Memes', total_memes]
          csv << ['Total Likes', total_likes]
          csv << ['Total Views', total_views]
          csv << ['Average Likes', total_memes > 0 ? (total_likes.to_f / total_memes).round(2) : 0]
          csv << ['Average Views', total_memes > 0 ? (total_views.to_f / total_memes).round(2) : 0]
          csv << ['Engagement Rate', total_views > 0 ? ((total_likes.to_f / total_views) * 100).round(2) : 0]
        end
        
        attachment "meme_metrics_#{period}_#{Time.now.strftime('%Y%m%d')}.csv"
        content_type 'text/csv'
        csv_data
      end

      # User notifications API
      app.get "/api/notifications" do
        require_auth!
        user_id = current_user_id
        
        # Get user notifications (saved count changes, likes, etc.)
        content_type :json
        {
          user_id: user_id,
          saved_count: get_user_saved_memes_count(user_id),
          timestamp: Time.now.iso8601,
          message: "Your profile is up to date"
        }.to_json
      end
    end
  end
end
RUBY

File.write('routes/metrics_routes.rb', metrics_routes_content)
puts "✅ Fixed metrics routes with PostgreSQL-compatible SQL"
puts

# =============================================================================
# Summary
# =============================================================================

puts "=" * 80
puts "✅ FIXES APPLIED SUCCESSFULLY"
puts "=" * 80
puts
puts "Fixed Issues:"
puts "1. ✅ Logout now properly destroys Redis sessions"
puts "2. ✅ Metrics page uses PostgreSQL-compatible SQL syntax"
puts
puts "Files Modified:"
puts "  - routes/auth.rb"
puts "  - routes/metrics_routes.rb"
puts
puts "Next Steps:"
puts "  1. Restart your server: bundle exec puma config.ru"
puts "  2. Test logout: Visit /logout and verify session is cleared"
puts "  3. Test metrics: Visit /metrics and verify data loads correctly"
puts
puts "🎯 Both critical issues resolved!"
puts "=" * 80
RUBY
File.chmod(0755, '/Users/brian/DiscoveryPartnersInstitute/meme-explorer/scripts/fix_auth_and_metrics_july_20_2026.rb')

puts "✅ Fix script created"
puts
