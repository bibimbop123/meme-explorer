# Meme Battles Routes
# Head-to-head meme voting with ELO ratings

module MemeExplorer
  module Routes
    class Battles
      # ELO calculation constants
      K_FACTOR = 32 # Sensitivity to wins/losses
      
      def self.register(app)
        # Get a new battle (two random memes)
        app.get '/battles/new' do
          begin
            # Get memes with valid images
            memes = app.class::MEME_CACHE[:memes] || []
            memes = memes.select { |m| m['url'] || m['file'] }
            
            halt 404, "Not enough memes for battle" if memes.size < 2
            
            # Select two random different memes
            battle_memes = memes.sample(2)
            
            @meme_a = battle_memes[0]
            @meme_b = battle_memes[1]
            
            # Get ELO ratings
            @meme_a_elo = get_elo(@meme_a['url'] || @meme_a['file'])
            @meme_b_elo = get_elo(@meme_b['url'] || @meme_b['file'])
            
            erb :battle
          rescue => e
            puts "❌ [BATTLES] Error creating battle: #{e.message}"
            halt 500, "Failed to create battle"
          end
        end
        
        # Submit battle result
        app.post '/battles/result' do
          meme_a_url = params[:meme_a]
          meme_b_url = params[:meme_b]
          winner_url = params[:winner]
          
          halt 400, { error: 'Missing parameters' }.to_json unless meme_a_url && meme_b_url && winner_url
          halt 400, { error: 'Invalid winner' }.to_json unless [meme_a_url, meme_b_url].include?(winner_url)
          
          begin
            user_id = session[:user_id]
            session_id = session.object_id.to_s
            
            # Record battle
            DB.execute(
              "INSERT INTO meme_battles (meme_a_url, meme_b_url, winner_url, user_id, session_id)
               VALUES (?, ?, ?, ?, ?)",
              [meme_a_url, meme_b_url, winner_url, user_id, session_id]
            )
            
            # Update ELO ratings
            loser_url = winner_url == meme_a_url ? meme_b_url : meme_a_url
            update_elo_ratings(winner_url, loser_url)
            
            # Award XP
            if user_id && defined?(GamificationHelpers)
              app.helpers.add_xp(user_id, :participate_battle) rescue nil
            end
            
            # Track action
            if defined?(ActivityTrackerService)
              ActivityTrackerService.record_action('battle', user_id || session_id)
            end
            
            # Get updated stats
            winner_stats = get_meme_stats(winner_url)
            loser_stats = get_meme_stats(loser_url)
            
            content_type :json
            {
              success: true,
              winner: {
                url: winner_url,
                elo: winner_stats[:elo],
                wins: winner_stats[:wins]
              },
              loser: {
                url: loser_url,
                elo: loser_stats[:elo],
                losses: loser_stats[:losses]
              }
            }.to_json
          rescue => e
            puts "❌ [BATTLES] Error recording result: #{e.message}"
            Sentry.capture_exception(e) if defined?(Sentry)
            halt 500, { error: 'Failed to record battle' }.to_json
          end
        end
        
        # Get battle leaderboard
        app.get '/battles/leaderboard' do
          limit = (params[:limit] || 50).to_i
          sort_by = params[:sort] || 'elo'
          
          begin
            @top_memes = case sort_by
                         when 'elo'
                           DB.execute(
                             "SELECT * FROM meme_elo_ratings 
                              WHERE total_battles >= 3
                              ORDER BY elo_score DESC LIMIT ?",
                             [limit]
                           )
                         when 'wins'
                           DB.execute(
                             "SELECT * FROM meme_elo_ratings 
                              ORDER BY wins DESC LIMIT ?",
                             [limit]
                           )
                         when 'battles'
                           DB.execute(
                             "SELECT * FROM meme_elo_ratings 
                              ORDER BY total_battles DESC LIMIT ?",
                             [limit]
                           )
                         else
                           DB.execute(
                             "SELECT * FROM meme_elo_ratings 
                              ORDER BY elo_score DESC LIMIT ?",
                             [limit]
                           )
                         end
            
            if request.accept.include?('application/json')
              content_type :json
              @top_memes.to_json
            else
              erb :battle_leaderboard
            end
          rescue => e
            puts "❌ [BATTLES] Error fetching leaderboard: #{e.message}"
            @top_memes = []
            erb :battle_leaderboard
          end
        end
        
        # Get user battle stats
        app.get '/battles/stats/:user_id' do
          user_id = params[:user_id].to_i
          
          begin
            total_battles = DB.get_first_value(
              "SELECT COUNT(*) FROM meme_battles WHERE user_id = ?",
              [user_id]
            ).to_i
            
            favorite_memes = DB.execute(
              "SELECT winner_url, COUNT(*) as times_chosen
               FROM meme_battles
               WHERE user_id = ?
               GROUP BY winner_url
               ORDER BY times_chosen DESC
               LIMIT 10",
              [user_id]
            )
            
            content_type :json
            {
              total_battles: total_battles,
              favorite_memes: favorite_memes
            }.to_json
          rescue => e
            puts "❌ [BATTLES] Error fetching user stats: #{e.message}"
            content_type :json
            { total_battles: 0, favorite_memes: [] }.to_json
          end
        end
        
        private
        
        # Get ELO rating for a meme
        def self.get_elo(meme_url)
          result = DB.execute(
            "SELECT elo_score FROM meme_elo_ratings WHERE meme_url = ?",
            [meme_url]
          ).first
          
          result ? result['elo_score'].to_i : 1200 # Default ELO
        end
        
        # Get meme stats
        def self.get_meme_stats(meme_url)
          result = DB.execute(
            "SELECT * FROM meme_elo_ratings WHERE meme_url = ?",
            [meme_url]
          ).first
          
          if result
            {
              elo: result['elo_score'].to_i,
              wins: result['wins'].to_i,
              losses: result['losses'].to_i,
              total_battles: result['total_battles'].to_i,
              win_rate: result['win_rate'].to_f
            }
          else
            { elo: 1200, wins: 0, losses: 0, total_battles: 0, win_rate: 0.0 }
          end
        end
        
        # Update ELO ratings after a battle
        def self.update_elo_ratings(winner_url, loser_url)
          # Get current ratings
          winner_elo = get_elo(winner_url)
          loser_elo = get_elo(loser_url)
          
          # Calculate expected scores
          expected_winner = 1.0 / (1.0 + 10**((loser_elo - winner_elo) / 400.0))
          expected_loser = 1.0 / (1.0 + 10**((winner_elo - loser_elo) / 400.0))
          
          # Calculate new ratings
          new_winner_elo = (winner_elo + K_FACTOR * (1 - expected_winner)).round
          new_loser_elo = (loser_elo + K_FACTOR * (0 - expected_loser)).round
          
          # Update winner
          DB.execute(
            "INSERT INTO meme_elo_ratings (meme_url, elo_score, total_battles, wins)
             VALUES (?, ?, 1, 1)
             ON CONFLICT (meme_url) DO UPDATE SET
               elo_score = ?,
               total_battles = total_battles + 1,
               wins = wins + 1,
               updated_at = CURRENT_TIMESTAMP",
            [winner_url, new_winner_elo, new_winner_elo]
          )
          
          # Update loser
          DB.execute(
            "INSERT INTO meme_elo_ratings (meme_url, elo_score, total_battles, losses)
             VALUES (?, ?, 1, 1)
             ON CONFLICT (meme_url) DO UPDATE SET
               elo_score = ?,
               total_battles = total_battles + 1,
               losses = losses + 1,
               updated_at = CURRENT_TIMESTAMP",
            [loser_url, new_loser_elo, new_loser_elo]
          )
        end
      end
    end
  end
end
