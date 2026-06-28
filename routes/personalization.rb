# frozen_string_literal: true
# routes/personalization.rb
# Personalization routes: taste evolution, saved memes, email capture

module Routes
  module PersonalizationRoutes
    def self.registered(app)

      app.get '/taste-evolution' do
        require_auth!
        user_id = current_user_id
        personalization = PersonalizationService.new(user_id)
        @taste_evolution = personalization.get_taste_evolution
        erb :taste_evolution
      end

      app.get '/saved' do
        require_auth!
        user_id = current_user_id
        personalization = PersonalizationService.new(user_id)
        @organized_saves = personalization.organize_saved_memes
        erb :saved_memes
      end

      app.post '/api/subscribe' do
        content_type :json
        email = begin
          JSON.parse(request.body.read)['email']
        rescue
          nil
        end
        unless email && email.match?(/\A[^@\s]+@[^@\s]+\z/)
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
          { success: false, message: 'Subscription failed' }.to_json
        end
      end

      app.post '/api/saved/remove' do
        content_type :json
        require_auth!
        data     = JSON.parse(request.body.read)
        meme_url = data['url']
        begin
          DB.execute(
            'DELETE FROM user_saved_memes WHERE user_id = ? AND meme_url = ?',
            [current_user_id, meme_url]
          )
          { success: true }.to_json
        rescue => e
          AppLogger.error('Remove saved error', error: e.message)
          { success: false }.to_json
        end
      end

    end
  end
end
