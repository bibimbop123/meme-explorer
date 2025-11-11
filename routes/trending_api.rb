gets '/api/v1/trending' do
  content_type :json
  
  time_window = params['time_window'] || '24h'
  sort_by = params['sort_by'] || 'trending'
  limit = [(params['limit'] || 20).to_i, 100].min
  cursor = params['cursor']
  
  valid_windows = ['1h', '24h', '7d', 'all_time']
  valid_sorts = ['trending', 'latest', 'most_liked', 'rising']
  
  return status(400) && { error: "Invalid time_window" }.to_json unless valid_windows.include?(time_window)
  return status(400) && { error: "Invalid sort_by" }.to_json unless valid_sorts.include?(sort_by)
  
  begin
    result = TrendingService.trending_memes(
      time_window: time_window,
      sort_by: sort_by,
      limit: limit,
      cursor: cursor
    )
    
    { success: true, data: result[:memes], pagination: result[:pagination], meta: { time_window: time_window, sort_by: sort_by, limit: limit } }.to_json
  rescue => e
    AppLogger.error("Trending API error: #{e.message}")
    status(500) && { error: 'Failed to fetch trending memes' }.to_json
  end
end

gets '/api/v1/trending/badges' do
  content_type :json
  { success: true, badges: [{ id: 'trending_now', label: 'Trending', emoji: '🔥', color: '#FF6B6B' }, { id: 'hot', label: 'Hot', emoji: '📈', color: '#FFD700' }] }.to_json
end
