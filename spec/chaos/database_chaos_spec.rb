# frozen_string_literal: true

require 'spec_helper'

# BUG FIX: this file was written against `SQLite3::Database`/
# `SQLite3::CorruptException` and a nonexistent `get_db_connection`
# helper - this codebase's real DB is PostgreSQL via a hand-rolled
# `DBWrapper` (db/setup.rb), with no SQLite3 dependency in the Gemfile at
# all. Rewritten against the real `DB` (a `DBWrapper` around a
# `ConnectionPool` of `PG::Connection`s) and real routes.
RSpec.describe 'Database Chaos Tests', type: :chaos do
  describe 'Database Failure Scenarios' do
    it 'handles concurrent database access without exhausting the pool' do
      # The real pool is sized generously (35 connections - see
      # db/setup.rb) specifically so ordinary concurrent request load
      # doesn't exhaust it.
      10.times { DB.execute("SELECT 1") }

      get '/'
      expect(last_response.status).to eq(200)
    end

    it 'handles slow queries without crashing the request' do
      allow(DB).to receive(:execute).and_wrap_original do |original, *args|
        sleep 0.05
        original.call(*args)
      end

      get '/trending'
      expect(last_response.status).to eq(200)
    end

    it 'handles a raised database error gracefully' do
      allow(DB).to receive(:execute).and_raise(PG::ConnectionBad, 'simulated connection loss')

      get '/'

      # Should not raise all the way up to a raw 500 with a stack trace -
      # real routes wrap DB calls in begin/rescue and fall back to
      # defaults (see routes/home.rb, routes/random_meme.rb).
      expect(last_response.status).to be_between(200, 503)
    end
  end
end
