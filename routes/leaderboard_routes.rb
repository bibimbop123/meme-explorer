# frozen_string_literal: true
# routes/leaderboard_routes.rb - extracted from app.rb

module Routes
  module LeaderboardRoutes
    def self.registered(app)
    app.get "/leaderboard" do
      AppLogger.info("🏆 [LEADERBOARD] Route accessed")

      # Initialize all variables with safe defaults
      @leaderboard_type = params[:type]&.to_sym || :all_time
      @current_period = params[:period]
      @leaderboard = []
      @user_rank = nil
      @rank_change = nil
      @nearby = []
      @insights = []
      @challenge = nil
      @challenge_progress = nil
      @previous_periods = []

      # PRIMARY: Try advanced LeaderboardService (gracefully falls back to simple version)
      @leaderboard = begin
        if @leaderboard_type == :weekly && @current_period.nil?
          # For weekly default, try simple method first (faster)
          AppLogger.info("🏆 [LEADERBOARD] Using simple weekly leaderboard")
          get_leaderboard || []
        else
          # For other types or specific periods, use LeaderboardService
          AppLogger.info("🏆 [LEADERBOARD] Using LeaderboardService (type: #{@leaderboard_type})")
          LeaderboardService.get_leaderboard(
            type: @leaderboard_type,
            period: @current_period,
            limit: 25
          )
        end
      rescue => e
        AppLogger.error("⚠️ [LEADERBOARD] Advanced service failed: #{e.message}, falling back to simple")
        @leaderboard_type = :weekly  # Reset to weekly on error
        get_leaderboard rescue []
      end

      AppLogger.info("🏆 [LEADERBOARD] Got #{@leaderboard.size} entries")

      # Mark current user in leaderboard
      if current_user_id && @leaderboard.any?
        @leaderboard.each do |entry|
          entry['is_current_user'] = (entry['user_id'].to_i == current_user_id)
        end
      end

      # ADVANCED FEATURES (only if user is logged in)
      if current_user_id
        # Get user's rank with advanced details
        @user_rank = begin
          LeaderboardService.get_user_rank(
            current_user_id,
            type: @leaderboard_type,
            period: @current_period
          )
        rescue => e
          AppLogger.error("⚠️ [LEADERBOARD] get_user_rank failed: #{e.message}")
          # Fallback: find in current leaderboard
          @leaderboard.find { |e| e['user_id'].to_i == current_user_id }
        end

        if @user_rank
          # Get rank change from previous period
          @rank_change = begin
            LeaderboardService.rank_change(current_user_id, type: @leaderboard_type)
          rescue => e
            AppLogger.error("⚠️ [LEADERBOARD] rank_change failed: #{e.message}")
            nil
          end

          # Get nearby competitors
          @nearby = begin
            LeaderboardService.get_nearby_ranks(
              current_user_id,
              type: @leaderboard_type,
              range: 5,
              period: @current_period
            )
          rescue => e
            AppLogger.error("⚠️ [LEADERBOARD] get_nearby_ranks failed: #{e.message}")
            []
          end

          # Generate insights
          current_rank = @user_rank['rank'].to_i
          if current_rank > 10
            gap_analysis = begin
              LeaderboardService.rank_gap_analysis(
                current_user_id,
                10,
                type: @leaderboard_type,
                period: @current_period
              )
            rescue => e
              AppLogger.error("⚠️ [LEADERBOARD] rank_gap_analysis failed: #{e.message}")
              nil
            end

            if gap_analysis
              @insights << {
                icon: '🎯',
                text: "You need #{gap_analysis[:gap]} more points to reach the top 10!"
              }
            end
          elsif current_rank <= 3
            @insights << {
              icon: '🏆',
              text: "Amazing! You're in the top 3!"
            }
          elsif current_rank <= 10
            @insights << {
              icon: '⭐',
              text: "Great job! You're in the top 10!"
            }
          end

          # Rank improvement insight
          if @rank_change && @rank_change[:change] && @rank_change[:change] > 0
            @insights << {
              icon: '📈',
              text: "You've climbed #{@rank_change[:change]} positions!"
            }
          end
        end
      end

      # Get weekly challenge
      @challenge = current_weekly_challenge rescue nil

      # Generate previous periods for dropdown (for weekly/monthly types)
      if @leaderboard_type == :weekly || @leaderboard_type == :monthly
        @previous_periods = begin
          periods = []
          current = LeaderboardService.current_period(@leaderboard_type)
          5.times do |i|
            period = LeaderboardService.previous_period(@leaderboard_type, current)
            label = if @leaderboard_type == :weekly
              date = Date.strptime(period.to_s + '1', '%Y%U%u')
              "Week of #{date.strftime('%b %d, %Y')}"
            else
              year = period.to_s[0..3]
              month = period.to_s[4..5]
              Date.new(year.to_i, month.to_i).strftime('%B %Y')
            end

            periods << { value: period, label: label }
            current = period
          end
          periods
        rescue => e
          AppLogger.error("⚠️ [LEADERBOARD] previous_periods generation failed: #{e.message}")
          []
        end
      end

      AppLogger.info("🏆 [LEADERBOARD] Rendering view...")
      erb :leaderboard
    end

    # API Endpoint for AJAX leaderboard updates
    app.get "/api/leaderboard" do
      content_type :json

      begin
        type = (params[:type] || 'weekly').to_sym
        period = params[:period]
        limit = (params[:limit] || 25).to_i
        offset = (params[:offset] || 0).to_i

        # Get leaderboard data
        leaderboard = LeaderboardService.get_leaderboard(
          type: type,
          period: period,
          limit: limit,
          offset: offset
        )

        # Mark current user
        if current_user_id
          leaderboard.each do |entry|
            entry['is_current_user'] = (entry['user_id'].to_i == current_user_id)
          end
        end

        # Get user rank and nearby competitors
        user_rank = nil
        rank_change = nil
        nearby = []
        insights = {}

        if current_user_id
          user_rank = LeaderboardService.get_user_rank(
            current_user_id,
            type: type,
            period: period
          )

          if user_rank
            rank_change = LeaderboardService.rank_change(current_user_id, type: type)
            nearby = LeaderboardService.get_nearby_ranks(
              current_user_id,
              type: type,
              range: 5,
              period: period
            )

            # Generate insights
            current_rank = user_rank['rank'].to_i
            if current_rank > 10
              gap_analysis = LeaderboardService.rank_gap_analysis(
                current_user_id,
                10,
                type: type,
                period: period
              )
              insights[:gap_to_top10] = gap_analysis[:gap] if gap_analysis
            end
          end
        end

        # Get challenge
        challenge = current_weekly_challenge

        {
          success: true,
          leaderboard: leaderboard,
          user_rank: user_rank,
          rank_change: rank_change,
          nearby: nearby,
          insights: insights,
          challenge: challenge
        }.to_json
      rescue => e
        AppLogger.error("❌ API Leaderboard error: #{e.message}")
        {
          success: false,
          error: e.message
        }.to_json
      end
    end

    # -----------------------
    # User Profile & Features
    end
  end
end
