# frozen_string_literal: true

module Routes
  module UtilityRoutes
    def self.registered(app)
      app.get '/ads.txt' do
        content_type 'text/plain'
        File.read(File.expand_path('../ads.txt', __dir__))
      end
      # Random JSON and Search belong to RandomMeme and Memes/SearchService.
      # Superseded, unreachable copies were removed.
    end
  end
end
