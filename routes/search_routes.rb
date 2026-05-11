# routes/search_routes.rb
# Search functionality - HTML and JSON endpoints

module Routes
  module SearchRoutes
    def self.registered(app)
      # Main search endpoint (supports HTML and JSON)
      app.get "/search" do
        query = params[:q]
        
        if request.accept.include?("application/json")
          # JSON API endpoint
          results = search_memes(query)
          content_type :json
          {
            query: query,
            results: results.map { |m| {
              title: m["title"],
              url: m["url"] || m["file"],
              file: m["file"],
              subreddit: m["subreddit"],
              likes: m["likes"].to_i,
              views: m["views"].to_i,
              source: m["file"] ? "local" : "reddit"
            }},
            total: results.size
          }.to_json
        else
          # HTML view
          @results = search_memes(query)
          @query = query
          erb :search
        end
      end
      
      # Dedicated JSON search API endpoint
      app.get "/api/search.json" do
        query = params[:q]
        results = search_memes(query)
        
        content_type :json
        {
          query: query,
          results: results.map { |m| {
            title: m["title"],
            url: m["url"] || m["file"],
            file: m["file"],
            subreddit: m["subreddit"],
            likes: m["likes"].to_i,
            views: m["views"].to_i,
            source: m["file"] ? "local" : "reddit",
            engagement_score: (m["likes"].to_i * 2 + m["views"].to_i)
          }},
          total: results.size
        }.to_json
      end
    end
  end
end
