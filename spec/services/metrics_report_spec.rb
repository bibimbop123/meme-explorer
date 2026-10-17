require_relative '../spec_helper'

RSpec.describe MetricsReport do
  let(:now) { Time.utc(2026, 10, 17, 12, 30) }

  before do
    DB.execute('INSERT INTO meme_stats (url, title, subreddit, likes, views) VALUES (?, ?, ?, ?, ?)',
      ['/fixture.jpeg', '<script>bad</script>', 'fixture', 90, 900])
    [0.5, 2, 10, 40].each do |days|
      %w[view like unlike].each do |event|
        DB.execute('INSERT INTO meme_activity_log (meme_url, activity_type, created_at) VALUES (?, ?, ?)',
          ['/fixture.jpeg', event, (now - days * 86_400).iso8601])
      end
    end
    DB.execute("INSERT INTO meme_activity_log (meme_url, activity_type, created_at) VALUES (?, 'view', ?)",
      ['/fixture.jpeg', (now + 100).iso8601])
  end

  { '24h' => 1, '7d' => 2, '30d' => 3 }.each do |period, count|
    it "uses event counts consistently for #{period}, not recently updated lifetime counters" do
      report = described_class.build(period: period, now: now)
      expect(report).to include(total_memes: 1, total_views: count, total_likes: count)
      expect(report[:chart_views].sum).to eq(count)
      expect(report[:chart_likes].sum).to eq(count)
      expect(report[:top_memes].first['views'].to_i).to eq(count)
      expect(report[:top_subreddits].first['total_likes'].to_i).to eq(count)
    end
  end

  it 'labels all-time stored totals separately from the last-30-day event chart' do
    report = described_class.build(period: 'all', now: now)
    expect(report).to include(total_views: 900, total_likes: 90, source: 'cumulative stored counters')
    expect(report[:chart_views].sum).to eq(3)
  end

  it 'includes the oldest partial hour and the current partial hour' do
    DB.execute("INSERT INTO meme_activity_log (meme_url, activity_type, created_at) VALUES (?, 'view', ?)",
      ['/fixture.jpeg', (now - 86_400 + 1).iso8601])
    report = described_class.build(period: '24h', now: now)
    expect(report[:chart_dates].size).to eq(25)
    expect(report[:chart_views].sum).to eq(report[:total_views])
    expect(report[:chart_views].first).to eq(1)
  end

  it 'rejects unknown periods' do
    expect { described_class.build(period: 'invalid') }.to raise_error(ArgumentError)
  end

  %w[24h 7d 30d].each do |period|
    it "includes exact #{period} boundaries and excludes events just outside them" do
      DB.execute('DELETE FROM meme_activity_log')
      start = now - described_class::PERIODS.fetch(period)
      [start - 1, start, now, now + 1].each do |timestamp|
        DB.execute("INSERT INTO meme_activity_log (meme_url, activity_type, created_at) VALUES (?, 'view', ?)",
          ['/fixture.jpeg', timestamp.iso8601])
      end
      report = described_class.build(period: period, now: now)
      expect(report[:total_views]).to eq(2)
      expect(report[:chart_views].sum).to eq(2)
      expect(report[:top_memes].first['views'].to_i).to eq(2)
    end
  end
end