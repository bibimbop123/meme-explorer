# Phase 2: Schema.org Structured Data for Better SEO
module SchemaHelpers
  # Generate JSON-LD schema for meme page
  def meme_schema(meme)
    {
      "@context": "https://schema.org",
      "@type": "ImageObject",
      "name": meme[:title] || "Meme from Reddit",
      "description": meme[:description] || "Funny meme from r/#{meme[:subreddit]}",
      "contentUrl": meme[:image_url],
      "thumbnailUrl": meme[:thumbnail_url] || meme[:image_url],
      "uploadDate": meme[:created_at] || Time.now.iso8601,
      "author": {
        "@type": "Person",
        "name": meme[:author] || "Unknown"
      },
      "sourceOrganization": {
        "@type": "Organization",
        "name": "Reddit",
        "url": "https://reddit.com/r/#{meme[:subreddit]}"
      },
      "license": "https://www.reddit.com/wiki/licensing"
    }.to_json
  end
  
  # Generate WebSite schema for homepage
  def website_schema
    {
      "@context": "https://schema.org",
      "@type": "WebSite",
      "name": "Meme Explorer",
      "description": "Discover trending memes from Reddit",
      "url": request.base_url,
      "potentialAction": {
        "@type": "SearchAction",
        "target": "#{request.base_url}/search?q={search_term_string}",
        "query-input": "required name=search_term_string"
      }
    }.to_json
  end
  
  # Generate BreadcrumbList schema
  def breadcrumb_schema(items)
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      "itemListElement": items.map.with_index do |item, index|
        {
          "@type": "ListItem",
          "position": index + 1,
          "name": item[:name],
          "item": item[:url]
        }
      end
    }.to_json
  end
end
