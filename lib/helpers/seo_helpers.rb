# lib/helpers/seo_helpers.rb
# View helpers for SEO meta tags and structured data
#
# Usage: Include in Sinatra app with `helpers SeoHelpers`

module SeoHelpers
  # Render meta tags from SEO service data
  def render_meta_tags(meta_data = nil)
    meta_data ||= @seo_meta || {}
    
    tags = []
    
    # Basic meta tags
    tags << %Q(<title>#{escape_html(meta_data[:title])}</title>) if meta_data[:title]
    tags << %Q(<meta name="description" content="#{escape_html(meta_data[:description])}">) if meta_data[:description]
    tags << %Q(<meta name="keywords" content="#{escape_html(meta_data[:keywords])}">) if meta_data[:keywords]
    tags << %Q(<meta name="author" content="#{escape_html(meta_data[:author])}">) if meta_data[:author]
    tags << %Q(<meta name="robots" content="#{meta_data[:robots]}">) if meta_data[:robots]
    tags << %Q(<link rel="canonical" href="#{meta_data[:canonical]}">) if meta_data[:canonical]
    
    # Open Graph tags
    if og = meta_data[:og]
      tags << %Q(<meta property="og:type" content="#{og[:type]}">) if og[:type]
      tags << %Q(<meta property="og:url" content="#{og[:url]}">) if og[:url]
      tags << %Q(<meta property="og:title" content="#{escape_html(og[:title])}">) if og[:title]
      tags << %Q(<meta property="og:description" content="#{escape_html(og[:description])}">) if og[:description]
      tags << %Q(<meta property="og:image" content="#{og[:image]}">) if og[:image]
      tags << %Q(<meta property="og:image:secure_url" content="#{og[:image_secure_url]}">) if og[:image_secure_url]
      tags << %Q(<meta property="og:image:type" content="#{og[:image_type]}">) if og[:image_type]
      tags << %Q(<meta property="og:image:width" content="#{og[:image_width]}">) if og[:image_width]
      tags << %Q(<meta property="og:image:height" content="#{og[:image_height]}">) if og[:image_height]
      tags << %Q(<meta property="og:image:alt" content="#{escape_html(og[:image_alt])}">) if og[:image_alt]
      tags << %Q(<meta property="og:site_name" content="#{escape_html(og[:site_name])}">) if og[:site_name]
      tags << %Q(<meta property="og:locale" content="#{og[:locale]}">) if og[:locale]
    end
    
    # Twitter Card tags
    if twitter = meta_data[:twitter]
      tags << %Q(<meta name="twitter:card" content="#{twitter[:card]}">) if twitter[:card]
      tags << %Q(<meta name="twitter:url" content="#{twitter[:url]}">) if twitter[:url]
      tags << %Q(<meta name="twitter:title" content="#{escape_html(twitter[:title])}">) if twitter[:title]
      tags << %Q(<meta name="twitter:description" content="#{escape_html(twitter[:description])}">) if twitter[:description]
      tags << %Q(<meta name="twitter:image" content="#{twitter[:image]}">) if twitter[:image]
      tags << %Q(<meta name="twitter:image:alt" content="#{escape_html(twitter[:image_alt])}">) if twitter[:image_alt]
      tags << %Q(<meta name="twitter:creator" content="#{twitter[:creator]}">) if twitter[:creator]
      tags << %Q(<meta name="twitter:site" content="#{twitter[:site]}">) if twitter[:site]
    end
    
    # Additional meta tags
    tags << %Q(<meta name="theme-color" content="#{meta_data[:theme_color]}">) if meta_data[:theme_color]
    tags << %Q(<meta name="apple-mobile-web-app-capable" content="#{meta_data[:apple_mobile_web_app_capable]}">) if meta_data[:apple_mobile_web_app_capable]
    tags << %Q(<meta name="apple-mobile-web-app-status-bar-style" content="#{meta_data[:apple_mobile_web_app_status_bar_style]}">) if meta_data[:apple_mobile_web_app_status_bar_style]
    tags << %Q(<meta name="mobile-web-app-capable" content="#{meta_data[:mobile_web_app_capable]}">) if meta_data[:mobile_web_app_capable]
    
    tags.join("\n  ")
  end
  
  # Render JSON-LD structured data
  def render_json_ld(type, data = {})
    json_ld = SeoService.generate_json_ld(type, data, request)
    json_ld ? "  #{json_ld}" : ""
  end
  
  # Render multiple JSON-LD schemas
  def render_multiple_json_ld(schemas = [])
    json_ld = SeoService.generate_multiple_json_ld(schemas, request)
    json_ld ? "  #{json_ld}" : ""
  end
  
  # Set SEO meta for a page (call in route handlers)
  def set_seo_meta(type, data = {})
    @seo_meta = case type
    when :home
      SeoService.home_page_meta(request)
    when :trending
      SeoService.trending_page_meta(request)
    when :random
      SeoService.random_page_meta(request)
    when :leaderboard
      SeoService.leaderboard_page_meta(request)
    when :search
      SeoService.search_page_meta(data[:query], request)
    when :profile
      SeoService.profile_page_meta(data[:username], request)
    when :meme
      SeoService.meme_detail_meta(data[:meme], request)
    when :custom
      SeoService.generate_meta_tags(data, request)
    else
      SeoService.generate_meta_tags({}, request)
    end
  end
  
  # Set JSON-LD structured data (call in route handlers)
  def set_structured_data(*schemas)
    @structured_data = schemas
  end
  
  private
  
  def escape_html(text)
    return "" unless text
    text.to_s.gsub('&', '&amp;')
           .gsub('<', '&lt;')
           .gsub('>', '&gt;')
           .gsub('"', '&quot;')
           .gsub("'", '&#39;')
  end
end
