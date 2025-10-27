require 'sinatra/base'
require 'yaml'
require 'uri'
require 'net/http'
require 'json'

class MemeExplorer < Sinatra::Base
  configure :development do
    require 'sinatra/reloader'
    register Sinatra::Reloader
  end

  MEMES = YAML.load_file("./data/memes.yml").transform_keys(&:to_s)
  VIEW_COUNTS ||= Hash.new(0)

  enable :sessions

  POPULAR_SUBREDDITS = %w[dankmemes memes wholesomeMemes me_irl ProgrammerHumor].freeze

  # Home
  get '/' do
    erb :index
  end

  # Category page
  get '/category/:name' do
    @category_name = params[:name]
    @memes = MEMES[@category_name]
    halt 404, "Category not found" unless @memes
    erb :category
  end

  # Random meme
  get '/random' do
    session[:seen_memes] ||= []

    memes = fetch_fresh_memes.reject { |m| session[:seen_memes].include?(m["url"]) }

    if memes.empty?
      # fallback to local memes
      category, local_memes = MEMES.to_a.sample
      memes = local_memes
      @category_name = category
    else
      @category_name = "Reddit Memes"
    end

    @meme = memes.sample
    @image_src = @meme["url"] || @meme["file"]  # <--- unified key
    session[:seen_memes] << @meme["url"] if @meme["url"]

    VIEW_COUNTS[@meme["title"]] += 1
    @views = VIEW_COUNTS[@meme["title"]]

    erb :meme
  end

  # Search memes
  get '/search' do
    query = params[:q].to_s.downcase
    @results = MEMES.flat_map do |category, memes|
      memes.select { |m| m["title"].downcase.include?(query) }
           .map { |m| [category, m] }
    end
    erb :search_results
  end

  # Single meme from category
  get '/category/:category/meme/:title' do
    @category_name = params[:category]
    category_memes = MEMES[@category_name]
    halt 404, "Category not found" unless category_memes

    title = URI.decode_www_form_component(params[:title])
    @meme = category_memes.find { |m| m["title"] == title }
    halt 404, "Meme not found" unless @meme

    @image_src = @meme["url"] || @meme["file"]  # <--- unified key
    VIEW_COUNTS[@meme["title"]] += 1
    @views = VIEW_COUNTS[@meme["title"]]

    erb :meme
  end

  # API memes page
  get '/api_memes' do
    @api_memes = fetch_api_memes
    erb :api_memes
  end

  # Like/unlike meme
  post '/like' do
    content_type :json
    begin
      meme_url = params[:url]
      session[:liked_memes] ||= []

      if session[:liked_memes].include?(meme_url)
        session[:liked_memes].delete(meme_url)
        liked = false
      else
        session[:liked_memes] << meme_url
        liked = true
      end

      { liked: liked }.to_json
    rescue => e
      status 500
      { error: e.message }.to_json
    end
  end

  # Fetch fresh memes from Reddit API
  def fetch_fresh_memes
    subreddit = POPULAR_SUBREDDITS.sample
    url = URI("https://meme-api.com/gimme/#{subreddit}/10")

    response = Net::HTTP.get(url)
    data = JSON.parse(response)
    memes = data["memes"] || []

    memes.map do |m|
      {
        "title" => m["title"],
        "url" => m["url"],
        "postLink" => m["postLink"],
        "subreddit" => m["subreddit"]
      }
    end
  rescue StandardError => e
    puts "API Error in fetch_fresh_memes: #{e.message}"
    []
  end

  # Fetch multiple API memes
  def fetch_api_memes(count = 18)
    url = URI("https://meme-api.com/gimme/#{count}")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)

    memes = if data["memes"]
              data["memes"]
            elsif data["url"]
              [data]
            else
              []
            end

    memes.map do |m|
      {
        "title" => m["title"],
        "url" => m["url"],
        "postLink" => m["postLink"],
        "subreddit" => m["subreddit"]
      }
    end
  rescue StandardError => e
    puts "API Error: #{e.message}"
    []
  end

  run! if app_file == $0
end
