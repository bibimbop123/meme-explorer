# frozen_string_literal: true

require 'spec_helper'
require 'json-schema'

RSpec.describe 'API Schema Validation', type: :contract do
  describe 'Internal API Schemas' do
    let(:meme_schema) do
      {
        type: 'object',
        required: ['id', 'title', 'url', 'category'],
        properties: {
          id: { type: 'integer' },
          title: { type: 'string' },
          url: { type: 'string', format: 'uri' },
          category: { type: 'string' },
          likes: { type: 'integer', minimum: 0 },
          views: { type: 'integer', minimum: 0 },
          created_at: { type: 'string', format: 'date-time' }
        }
      }
    end

    it 'validates meme response schema' do
      get '/api/memes/1'
      
      expect(last_response).to be_ok
      expect(JSON::Validator.validate!(meme_schema, json_response)).to be true
    end

    it 'validates meme list response' do
      list_schema = {
        type: 'object',
        required: ['memes', 'total', 'page'],
        properties: {
          memes: { type: 'array', items: meme_schema },
          total: { type: 'integer' },
          page: { type: 'integer' },
          per_page: { type: 'integer' }
        }
      }
      
      get '/api/memes'
      
      expect(last_response).to be_ok
      expect(JSON::Validator.validate!(list_schema, json_response)).to be true
    end

    it 'validates error response schema' do
      error_schema = {
        type: 'object',
        required: ['error', 'message'],
        properties: {
          error: { type: 'string' },
          message: { type: 'string' },
          code: { type: 'integer' },
          details: { type: 'object' }
        }
      }
      
      get '/api/memes/999999'
      
      expect(last_response.status).to eq(404)
      expect(JSON::Validator.validate!(error_schema, json_response)).to be true
    end
  end

  def json_response
    JSON.parse(last_response.body)
  end
end
