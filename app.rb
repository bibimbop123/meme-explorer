require 'sinatra/base'
require 'sinatra/reloader'
require 'yaml'

class MemeExplorer < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  MEMES = YAML.load_file("./data/memes.yml").transform_keys(&:to_s)

  
  VIEW_COUNTS ||= Hash.new(0)

  get '/' do
    erb :index
  end

  get '/category/:name' do
    @category_name = params[:name]         # string keys
    @memes = MEMES[@category_name]
    halt 404, "Category not found" unless @memes
    erb :category
  end
  
  
  
  get '/random' do
    category, memes = MEMES.to_a.sample
    @meme = memes.sample
    @category_name = category
    erb :meme
  end

  get '/search' do
    query = params[:q].to_s.downcase
    @results = MEMES.flat_map do |category, memes|
      memes.select { |m| m[:title].downcase.include?(query) }
           .map { |m| [category, m] }
    end
    erb :search_results
  end


  get '/category/:category/meme/:title' do
    @category_name = params[:category]     # string keys
    category_memes = MEMES[@category_name]
    halt 404, "Category not found" unless category_memes
  
    title = URI.decode_www_form_component(params[:title])
    @meme = category_memes.find { |m| m["title"] == title }
    halt 404, "Meme not found" unless @meme
  
    VIEW_COUNTS[@meme["title"]] += 1
    @views = VIEW_COUNTS[@meme["title"]]
    erb :meme
  end
  
  

  run! if app_file == $0
end
