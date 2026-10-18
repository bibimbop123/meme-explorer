# frozen_string_literal: true
require 'digest'
require 'json'
require_relative '../security/media_url'

# Identity v1 preserves existing engagement URL keys. It does not claim that two
# different CDN URLs represent different creative works, or deduplicate reposts.
class MemeIdentityService
  def self.register(meme, db: DB)
    return nil unless meme.is_a?(Hash)
    url = MediaUrl.safe(meme['url'] || meme['file'])
    return nil unless url
    id = Digest::SHA256.hexdigest("meme-url-v1:#{url}")
    snapshot = meme.slice('title', 'subreddit', 'permalink', 'media_type', 'thumbnail_url', 'width', 'height', 'is_gallery', 'gallery_images', 'is_crosspost', 'original_subreddit').merge('url' => url)
    # Bound persisted untrusted payloads; rendering must still validate/escape.
    payload = JSON.generate(snapshot)
    return nil if payload.bytesize > 131_072
    db.execute(
      'INSERT INTO meme_catalog (id, media_url, payload) VALUES (?, ?, ?::jsonb) ON CONFLICT (id) DO NOTHING',
      [id, url, payload]
    )
    id
  end

  def self.find(id, db: DB)
    return nil unless id.is_a?(String) && id.match?(/\A[a-f0-9]{64}\z/)
    row = db.execute('SELECT payload FROM meme_catalog WHERE id = ? AND removed_at IS NULL', [id]).first
    return nil unless row
    payload = row['payload'].is_a?(Hash) ? row['payload'] : JSON.parse(row['payload'])
    payload if payload.is_a?(Hash) && MediaUrl.safe(payload['url'])
  end
end