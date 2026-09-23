# routes/search_routes.rb
# Search functionality - HTML and JSON endpoints
#
# BUG FIX (reliability audit): this file duplicated `GET /search` and
# `GET /api/search.json` from routes/memes.rb - and unlike the other
# duplicate-route bugs found this session (where the LAST registered
# copy won), Sinatra's `route!` uses the FIRST matching route, and
# `routes/memes.rb` (`Routes::Memes`) is `register`ed before
# `Routes::SearchRoutes` in app.rb, so THIS file's copies were the dead,
# unreachable ones - confirmed directly: a request to `/search` executes
# routes/memes.rb's handler, not this one. This file's version was
# actually closer to correct (it called a real `search_memes(query)`
# helper from routes/utility_routes.rb, and inlined its own JSON
# formatting instead of calling a nonexistent `format_search_result`
# helper) - but being unreachable, none of that mattered. Removed
# entirely rather than left as a second, confusing "looks more correct"
# copy; routes/memes.rb's versions were fixed in place instead (see the
# BUG FIX comments there for the SearchService Hash-vs-Array mismatch,
# the missing `format_search_result` helper, the nonexistent
# `MemeService.cached_memes`, and the `request.accept.include?` bug that
# also existed here).
module Routes
  module SearchRoutes
    def self.registered(app)
    end
  end
end
