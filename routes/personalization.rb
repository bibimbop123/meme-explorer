# frozen_string_literal: true

# ==================================================================
# PERSONALIZATION ROUTES
# ==================================================================
# Routes for taste evolution, saved memes organization, email capture
# Week 3-4: Final push to 95/100 satisfaction

# Taste Evolution Timeline
get '/taste-evolution' do
  require_login
  
  user_id = session[:user_id]
  personalization = PersonalizationService.new(user_id)
  
  @taste_evolution = personalization.get_taste_evolution
  
  erb :taste_evolution
end

# Organized Saved Memes
get '/saved' do
  require_login
  
  user_id = session[:user_id]
  personalization = PersonalizationService.new(user_id)
  
  @organized_saves = personalization.organize_saved_memes
  
  erb :saved_memes
end

# API: Subscribe to daily digest
post '/api/subscribe' do
  content_type :json
  
  email = JSON.parse(request.body.read)['email'] rescue nil
  
  unless email && email.match?(/\A[^@\s]+@[^@\s]+\z/)
    halt 400, {success: false, message: 'Invalid email'}.to_json
  end
  
  begin
    # Store subscription
    DB.execute(
      "INSERT OR REPLACE INTO email_subscriptions (email, user_id, subscribed_at) VALUES (?, ?, ?)",
      [email, session[:user_id], Time.now.to_i]
    )
    
    session[:email_captured] = true
    
    {success: true, message: 'Subscribed successfully'}.to_json
  rescue => e
    logger.error "Subscription error: #{e.message}"
    {success: false, message: 'Subscription failed'}.to_json
  end
end

# API: Remove saved meme
post '/api/saved/remove' do
  content_type :json
  require_login
  
  data = JSON.parse(request.body.read)
  meme_url = data['url']
  
  begin
    DB.execute(
      "DELETE FROM user_saved_memes WHERE user_id = ? AND meme_url = ?",
      [session[:user_id], meme_url]
    )
    
    {success: true}.to_json
  rescue => e
    logger.error "Remove saved error: #{e.message}"
    {success: false}.to_json
  end
end

# Helper: Require login
def require_login
  redirect '/login' unless session[:user_id]
end
