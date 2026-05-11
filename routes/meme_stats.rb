# routes/meme_stats.rb
# Meme interaction routes - likes and broken image reports

module Routes
  module MemeStats
    def self.registered(app)
      # NOTE: /like endpoint removed - duplicate of routes/memes.rb POST /like
      # All like functionality is handled by MemeService.toggle_like
      
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
