# frozen_string_literal: true
require_relative '../security/media_url'

# Resolves supplied Reddit metadata only. Never downloads arbitrary website URLs.
module RedditMediaResolver
  def self.resolve(post, depth: 0)
    return nil unless post.is_a?(Hash) && depth < 4
    parents = post['crosspost_parent_list']
    if parents.is_a?(Array)
      parents.each do |parent|
        media = resolve(parent, depth: depth + 1)
        return media.merge('is_crosspost' => true, 'original_subreddit' => media['original_subreddit'] || parent['subreddit']) if media
      end
    end
    return nil if post['is_self'] || post['post_hint'] == 'rich:video'
    return nil if post['is_video']
    images = []
    gallery = post['gallery_data']
    metadata = post['media_metadata']
    if gallery.is_a?(Hash) && gallery['items'].is_a?(Array) && metadata.is_a?(Hash)
      gallery['items'].each do |item|
        next unless item.is_a?(Hash)
        info = metadata[item['media_id']]
        source = info['s'] if info.is_a?(Hash)
        next unless source.is_a?(Hash)
        url = raster(source['u']) || raster(source['gif'])
        images << { 'url' => url, 'caption' => item['caption'].to_s, 'width' => source['x'], 'height' => source['y'] } if url
      end
    end
    return { 'url' => images.first['url'], 'is_gallery' => true, 'gallery_images' => images } unless images.empty?
    url = raster(post['url'])
    url ||= "https://i.imgur.com/#{Regexp.last_match(1)}.jpg" if post['url'].is_a?(String) && post['url'].match(%r{\Ahttps://imgur\.com/([a-zA-Z0-9]+)\z})
    return { 'url' => url, 'media_type' => URI.parse(url).path.downcase.end_with?('.gif') ? 'gif' : 'image' } if url
    preview = post['preview']
    entries = preview['images'] if preview.is_a?(Hash)
    if entries.is_a?(Array)
      entries.each do |entry|
        source = entry['source'] if entry.is_a?(Hash)
        next unless source.is_a?(Hash)
        url = raster(source['url'])
        return { 'url' => url, 'width' => source['width'], 'height' => source['height'], 'media_type' => 'image' } if url
      end
    end
    nil
  end

  def self.raster(value)
    return nil unless value.is_a?(String)
    url = MediaUrl.safe(value.gsub('&amp;', '&'))
    return nil unless url && URI.parse(url).scheme == 'https'
    url if URI.parse(url).path.match?(/\.(?:jpe?g|png|webp|gif)\z/i)
  rescue URI::InvalidURIError
    nil
  end
end