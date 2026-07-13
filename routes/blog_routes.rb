# frozen_string_literal: true

# Blog Routes - Original Content for AdSense
module Routes
  module Blog
    def self.registered(app)
      app.get '/blog' do
        @posts = Dir.glob('data/blog_posts/*.yml').map do |file|
          YAML.load_file(file)
        end.sort_by { |p| p['published_at'] }.reverse
        
        erb :'blog/index'
      end
      
      app.get '/blog/:slug' do
        @post = YAML.load_file("data/blog_posts/#{params[:slug]}.yml")
        erb :'blog/post'
      rescue Errno::ENOENT
        halt 404, "Blog post not found"
      end
    end
  end
end
