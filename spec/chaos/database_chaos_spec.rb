# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Database Chaos Tests', type: :chaos do
  describe 'Database Failure Scenarios' do
    it 'handles database connection pool exhaustion' do
      # Exhaust connection pool
      connections = []
      10.times { connections << get_db_connection }
      
      # Should still handle new requests
      get '/'
      expect(last_response.status).to be_between(200, 503)
      
      # Cleanup
      connections.clear
    end

    it 'handles slow queries' do
      # Simulate slow query
      allow_any_instance_of(SQLite3::Database).to receive(:execute) do |*args|
        sleep 2
        []
      end
      
      Timeout.timeout(3) do
        get '/trending'
      end
      
      # Should timeout gracefully
      expect(last_response.status).to be_between(200, 504)
    end

    it 'handles database locks' do
      # Create a write lock
      Thread.new do
        db = get_db_connection
        db.execute('BEGIN EXCLUSIVE TRANSACTION')
        sleep 1
        db.execute('COMMIT')
      end
      
      sleep 0.1
      
      # Should handle read attempts
      get '/random'
      expect(last_response.status).to eq(200)
    end

    it 'handles corrupted database files' do
      # This is a simulation - don't actually corrupt the DB
      allow_any_instance_of(SQLite3::Database).to receive(:execute)
        .and_raise(SQLite3::CorruptException)
      
      get '/'
      
      expect(last_response.status).to eq(503)
      expect(last_response.body).to include('database')
    end
  end
end
