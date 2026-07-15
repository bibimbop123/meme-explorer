# frozen_string_literal: true

# Guides Routes - Original Content for AdSense Approval
# Created: July 7, 2026
# Purpose: Educational guides demonstrating expertise in meme curation

module Routes
  module Guides
    def self.registered(app)
      # Guide index page
      app.get '/guides' do
        erb :guides_index
      end

      # Core Feature Guides
      app.get '/guides/quality-system' do
        erb :'guides/quality_system'
      end

      app.get '/guides/personalization' do
        erb :'guides/personalization'
      end

      app.get '/guides/collections' do
        erb :'guides/collections'
      end

      app.get '/guides/discovery' do
        erb :'guides/discovery'
      end

      # User Onboarding Guides
      app.get '/guides/getting-started' do
        erb :'guides/getting_started'
      end

      app.get '/guides/meme-formats' do
        erb :'guides/meme_formats'
      end

      app.get '/guides/best-practices' do
        erb :'guides/best_practices'
      end

      app.get '/guides/community' do
        erb :'guides/community'
      end

      app.get '/guides/faq' do
        erb :'guides/faq'
      end
    end
  end
end
