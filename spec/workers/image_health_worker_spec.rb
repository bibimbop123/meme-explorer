# spec/workers/image_health_worker_spec.rb
require_relative '../spec_helper'
require_relative '../../app/workers/image_health_worker'

RSpec.describe ImageHealthWorker do
  let(:worker) { described_class.new }
  
  before(:each) do
    DB.execute(<<-SQL) rescue nil
      CREATE TABLE IF NOT EXISTS broken_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT UNIQUE NOT NULL,
        failure_count INTEGER DEFAULT 1,
        last_checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    SQL
    DB.execute("DELETE FROM broken_images") rescue nil
  end
  
  describe '#perform' do
    it 'checks image health' do
      expect { worker.perform }.not_to raise_error
    end
    
    it 'cleans up old broken image entries' do
      # Add old entry
      DB.execute("INSERT INTO broken_images (url, last_checked_at) VALUES (?, datetime('now', '-60 days'))",
        ['https://old.example.com/image.jpg'])
      
      worker.perform
      
      count = DB.get_first_value("SELECT COUNT(*) FROM broken_images WHERE url = ?",
        ['https://old.example.com/image.jpg'])
      expect(count).to eq(0)
    end
    
    it 'handles database errors gracefully' do
      allow(DB).to receive(:execute).and_raise(SQLite3::Exception.new('DB error'))
      expect { worker.perform }.not_to raise_error
    end
  end
end
