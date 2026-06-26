# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Backward Compatibility Tests', type: :contract do
  describe 'API Version Compatibility' do
    it 'maintains v1 API compatibility' do
      # Test legacy endpoint format
      get '/api/v1/memes/random'
      
      expect(last_response).to be_ok
      expect(json_response).to have_key('id')
      expect(json_response).to have_key('url')
    end

    it 'supports legacy parameter names' do
      # Old parameter name: 'category'
      get '/random?category=funny'
      expect(last_response).to be_ok
      
      # New parameter name: 'categories'
      get '/random?categories[]=funny'
      expect(last_response).to be_ok
    end

    it 'maintains legacy response format' do
      get '/api/memes/1.json'
      
      data = json_response
      
      # Legacy fields should still be present
      expect(data).to have_key('id')
      expect(data).to have_key('title')
      expect(data).to have_key('image_url')  # Legacy field name
    end
  end

  describe 'Database Schema Compatibility' do
    it 'handles missing optional columns' do
      # Simulate old schema without new columns
      meme = MemeService.find_by_id(1)
      expect(meme).to be_present
      
      # Should handle missing columns gracefully
      expect { meme['new_optional_field'] }.not_to raise_error
    end

    it 'maintains foreign key relationships' do
      # Verify relationships work across schema versions
      user = UserService.find_by_id(1)
      memes = MemeService.find_by_user_id(user['id'])
      
      expect(memes).to be_an(Array)
    end
  end

  describe 'Feature Flag Compatibility' do
    it 'handles disabled features gracefully' do
      ENV['FEATURE_NEW_ALGORITHM'] = 'false'
      
      get '/random'
      
      # Should fallback to old algorithm
      expect(last_response).to be_ok
    end
  end

  def json_response
    JSON.parse(last_response.body)
  end
end
