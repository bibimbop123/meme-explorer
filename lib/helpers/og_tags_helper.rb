# frozen_string_literal: true

# ============================================
# OPEN GRAPH TAGS HELPER
# ============================================
# Generates enhanced OG tags for social sharing
# Part of Week 2 Social Validation improvements

module OgTagsHelper
  def generate_og_tags(meme, request)
    collection_name = begin
      collection_name_for_subreddit(meme['subreddit'])
    rescue => e
      AppLogger.warn("generate_og_tags: collection_name lookup failed", error: e.message, subreddit: meme['subreddit'])
      'Meme Explorer'
    end
    curation_signal = begin
      get_curation_signal(meme)
    rescue => e
      AppLogger.warn("generate_og_tags: curation_signal lookup failed", error: e.message)
      nil
    end
    
    {
      'og:type' => 'website',
      'og:url' => request.url,
      'og:title' => "#{meme['title']} | #{collection_name}",
      'og:description' => generate_og_description(meme, curation_signal),
      'og:image' => meme['url'],
      'og:image:width' => '1200',
      'og:image:height' => '630',
      'og:site_name' => 'Meme Explorer',
      'twitter:card' => 'summary_large_image',
      'twitter:title' => meme['title'],
      'twitter:description' => generate_og_description(meme, curation_signal),
      'twitter:image' => meme['url']
    }
  end
  
  def generate_og_description(meme, curation_signal = nil)
    parts = []
    
    if curation_signal
      parts << curation_signal[:message]
    end
    
    likes = meme['likes'] || 0
    views = meme['views'] || 0
    
    if likes > 100
      parts << "#{likes} likes"
    end
    
    if views > 1000
      parts << "#{views} views"
    end
    
    description = parts.any? ? parts.join(' • ') : meme['title']
    description.length > 160 ? "#{description[0..157]}..." : description
  end
  
  def render_og_meta_tags(og_tags)
    og_tags.map do |property, content|
      %(<meta property="#{property}" content="#{content}">)
    end.join("
")
  end
end
