# frozen_string_literal: true
# routes/personalization.rb
# Personalization routes: taste evolution, saved memes, email capture
require_relative '../lib/services/discovery_preferences_store'

module Routes
  module PersonalizationRoutes
    def self.registered(app)
      app.helpers do
        def discovery_controls_enabled?
          ENV['ENABLE_DISCOVERY_CONTROLS'] != 'false'
        end

        def hidden_feed_communities
          return [] unless discovery_controls_enabled?
          discovery_preferences['hidden']
        end

        def discovery_preferences
          @discovery_preferences ||= DiscoveryPreferencesStore.call(feed_session_id)
        rescue DiscoveryPreferencesStore::Unavailable
          headers 'Cache-Control' => 'no-store, private'
          halt 503, 'Discovery controls are temporarily unavailable. Please retry; your settings have not been reset.'
        end

        def filter_feed_communities(pool)
          hidden = hidden_feed_communities
          return pool if hidden.empty? || pool.empty?
          filtered = pool.reject { |meme| hidden.include?(meme['subreddit'].to_s.downcase) }
          if filtered.empty?
            @meme = nil
            headers 'Cache-Control' => 'no-store, private'
            if request.path.end_with?('.json')
              halt 409, { error: 'No memes match your hidden-community settings. Reset them or try Search.', preferences_exhausted: true }.to_json
            end
            halt 200, erb(:feed_preferences_empty)
          end
          filtered
        end
      end

      app.post '/feed/preferences' do
        headers 'Cache-Control' => 'no-store, private'
        halt 404 unless discovery_controls_enabled?
        result = DiscoveryPreferencesStore.call(feed_session_id,
          action: params[:action].to_s, community: params[:community])
        halt 400, 'You can hide up to 20 communities. Reset or restore one first.' if result == :cap
        redirect '/random', 303
      rescue ArgumentError => e
        halt 400, e.message
      rescue DiscoveryPreferencesStore::Unavailable
        halt 503, 'Discovery controls are temporarily unavailable. Please retry; your settings have not been reset.'
      end

      app.get '/taste-evolution' do
        require_auth!
        headers 'Cache-Control' => 'no-store, private'
        status 410
        erb :taste_evolution
      end

      app.get '/saved' do
        require_auth!
        headers 'Cache-Control' => 'no-store, private'
        redirect '/profile'
      end

      app.post '/api/subscribe' do
        content_type :json
        email = begin
          JSON.parse(request.body.read)['email']
        rescue
          nil
        end
        unless email.is_a?(String) && email.bytesize <= 254 && email.match?(/\A[^@\s]+@[^@\s]+\z/)
          halt 400, { success: false, message: 'Invalid email' }.to_json
        end
        begin
          DB.execute(
            "INSERT INTO email_subscriptions (email, user_id, subscribed_at) " \
            "VALUES (?, ?, ?) " \
            "ON CONFLICT(email) DO UPDATE SET " \
            "user_id = EXCLUDED.user_id, subscribed_at = EXCLUDED.subscribed_at",
            [email, current_user_id, Time.now.to_i]
          )
          session[:email_captured] = true
          { success: true, message: 'Subscribed successfully' }.to_json
        rescue => e
          AppLogger.error('Subscription error', error: e.message)
          status 503
          { success: false, message: 'Subscription failed' }.to_json
        end
      end

      app.post '/api/saved/remove' do
        content_type :json
        require_auth!
        data = begin
          JSON.parse(request.body.read)
        rescue JSON::ParserError
          nil
        end
        meme_url = data['url'] if data.is_a?(Hash)
        unless meme_url.is_a?(String) && !meme_url.strip.empty? && meme_url.bytesize <= 4096
          halt 400, { success: false, error: 'A meme URL is required' }.to_json
        end
        begin
          DB.execute(
            'DELETE FROM saved_memes WHERE user_id = ? AND meme_url = ?',
            [current_user_id, meme_url]
          )
          { success: true }.to_json
        rescue => e
          AppLogger.error('Remove saved error', error: e.message)
          status 503
          { success: false }.to_json
        end
      end

    end
  end
end
