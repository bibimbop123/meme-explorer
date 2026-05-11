# routes/meme_stats.rb
# Meme interaction routes - likes and broken image reports

module Routes
  module MemeStats
    def self.registered(app)
      # Toggle like on a meme
      app.post "/like" do
        url = params[:url]
        halt 400, { error: "No URL provided" }.to_json unless url
      
        session[:liked_memes] ||= []
        session[:meme_like_counts] ||= {}
      
        # Toggle user's local like state
        liked_now = if session[:liked_memes].include?(url)
                      session[:liked_memes].delete(url)
                      false
                    else
                      session[:liked_memes] << url
                      true
                    end
      
        # Only count like once per session globally
        likes = toggle_like(url, liked_now, session)
      
        content_type :json
        { liked: liked_now, likes: likes }.to_json
      end

      # Report a broken image URL
      app.post "/report-broken-image" do
        url = params[:url]
        halt 400, { error: "No URL provided" }.to_json unless url

        report_broken_image(url)
        
        content_type :json
        { reported: true, message: "Broken image tracked" }.to_json
      end
    end
  end
end
