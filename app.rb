require 'sinatra'
require 'sinatra/reloader' if development?

# Sample meme data
MEMES = {
  funny: [
    { title: "WaterBottleSchoolBoy", file: "funny1.jpeg" },
    { title: "Birthyear", file: "funny2.jpeg" }
  ],
  wholesome: [
    { title: "RiskyJokes", file: "wholesome1.jpeg" },
    { title: "Finding a job", file: "wholesome2.jpeg" }
  ],
  dank: [
    { title: "Loading chunks of trees", file: "dank1.jpeg" },
    { title: "AWS-East-1", file: "dank2.jpeg" }
  ]
}

# Homepage
get '/' do
  erb :index
end

# Category page
get '/category/:name' do
  @category_name = params[:name].to_sym
  @memes = MEMES[@category_name]
  halt 404, "Category not found" unless @memes
  erb :category
end

# Meme page
get '/category/:category_name/meme/:title' do
  category = params[:category_name].to_sym
  @meme = MEMES[category].find { |m| m[:title] == params[:title] }
  halt 404, "Meme not found" unless @meme
  @category_name = category
  erb :meme
end
