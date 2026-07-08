# frozen_string_literal: true

# Guides Routes - Original Content for AdSense Approval
# Created: July 7, 2026
# Purpose: Educational guides demonstrating expertise in meme curation

class MemeExplorer < Sinatra::Base
  # Guide index page
  get '/guides' do
    erb :guides_index
  end

  # Core Feature Guides
  get '/guides/quality-system' do
    erb :'guides/quality_system'
  end

  get '/guides/personalization' do
    erb :'guides/personalization'
  end

  get '/guides/gamification' do
    erb :'guides/gamification'
  end

  get '/guides/collections' do
    erb :'guides/collections'
  end

  get '/guides/discovery' do
    erb :'guides/discovery'
  end

  # User Onboarding Guides
  get '/guides/getting-started' do
    erb :'guides/getting_started'
  end

  get '/guides/meme-formats' do
    erb :'guides/meme_formats'
  end

  get '/guides/best-practices' do
    erb :'guides/best_practices'
  end

  get '/guides/community' do
    erb :'guides/community'
  end

  get '/guides/faq' do
    erb :'guides/faq'
  end
end
