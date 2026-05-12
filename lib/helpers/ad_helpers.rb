# Ad Insertion Helpers
# Provides methods to intelligently insert ads into meme feeds
# Default: Every 12 memes (configurable via ENV)

module AdHelpers
  # Get ad frequency from environment or use default
  def ad_frequency
    ENV['AD_FREQUENCY']&.to_i || 12
  end
  
  # Check if user should see ads (premium users get ad-free experience)
  def should_show_ads?
    # Check if ads are globally disabled
    return false if ENV['DISABLE_ADS'] == 'true'
    
    # Check if current user is premium (if logged in)
    if session && session[:user_id]
      begin
        user = DB.execute("SELECT subscription_tier FROM users WHERE id = ?", [session[:user_id]]).first
        return false if user && (user['subscription_tier'] == 'premium' || user['subscription_tier'] == 'pro')
      rescue
        # If error checking premium status, default to showing ads
      end
    end
    
    true
  end
  
  # Determine if an ad should be shown at this position
  # @param index [Integer] Current item index (0-based)
  # @return [Boolean] True if ad should be shown before this item
  def show_ad_at_position?(index)
    return false if index == 0 # Never show ad as first item
    return false unless should_show_ads?
    
    # Show ad every N memes (e.g., positions 11, 23, 35... for frequency=12)
    ((index + 1) % ad_frequency) == 0
  end
  
  # Generate ad HTML for insertion
  # @param ad_index [Integer] Sequential ad number (for tracking)
  # @param format [String] Ad format: 'banner', 'square', 'native'
  # @param position [String] Grid position: 'top', 'bottom', 'left', 'right', 'left-1', 'left-2', 'right-1', 'right-2', etc.
  # @return [String] HTML for ad unit
  def render_ad_unit(ad_index = 0, format: 'square', position: nil)
    ad_id = "ad-unit-#{ad_index}"
    
    case format
    when 'banner'
      width = '728px'
      height = '90px'
      slot_id = ENV['GOOGLE_AD_SLOT_BANNER'] || 'BANNER_SLOT_ID'
    when 'native'
      width = '100%'
      height = 'auto'
      slot_id = ENV['GOOGLE_AD_SLOT_NATIVE'] || 'NATIVE_SLOT_ID'
    else # square (default for meme feeds)
      width = '300px'
      height = '250px'
      slot_id = ENV['GOOGLE_AD_SLOT_SQUARE'] || 'SQUARE_SLOT_ID'
    end
    
    # Add grid position attribute if specified
    position_attr = position ? " data-position=\"#{position}\"" : ""
    
    # Return placeholder if AdSense not configured
    unless ENV['GOOGLE_ADSENSE_CLIENT']
      return render_ad_placeholder(ad_id, width, height, position)
    end
    
    # Render actual AdSense unit
    <<-HTML
      <div class="ad-container" data-ad-index="#{ad_index}"#{position_attr}>
        <div class="ad-label">Advertisement</div>
        <ins class="adsbygoogle"
             style="display:inline-block;width:#{width};height:#{height}"
             data-ad-client="#{ENV['GOOGLE_ADSENSE_CLIENT']}"
             data-ad-slot="#{slot_id}"
             data-ad-format="#{format == 'native' ? 'auto' : 'rectangle'}"
             data-full-width-responsive="#{format == 'native' ? 'true' : 'false'}"></ins>
      </div>
    HTML
  end
  
  # Render placeholder ad (for development/testing)
  def render_ad_placeholder(ad_id, width, height, position = nil)
    position_attr = position ? " data-position=\"#{position}\"" : ""
    
    <<-HTML
      <div class="ad-container ad-placeholder" id="#{ad_id}" data-width="#{width}" data-height="#{height}"#{position_attr}>
        <div class="ad-label">Advertisement</div>
        <div class="ad-demo-content" style="width:#{width};height:#{height};">
          <div class="ad-demo-text">
            <strong>Ad Placeholder</strong><br>
            <small>Configure GOOGLE_ADSENSE_CLIENT in .env</small><br>
            <span style="font-size: 11px; opacity: 0.7;">#{width} × #{height}</span>
            #{position ? "<br><span style='font-size: 10px; color: #999;'>Grid: #{position}</span>" : ""}
          </div>
        </div>
      </div>
    HTML
  end
  
  # Insert ads into an array of items
  # @param items [Array] Array of memes or other content
  # @return [Array] Items with ads inserted at appropriate positions
  def insert_ads_into_array(items)
    return items unless should_show_ads?
    
    result = []
    ad_count = 0
    
    items.each_with_index do |item, index|
      # Insert ad before this item if appropriate
      if show_ad_at_position?(index)
        result << { type: 'ad', ad_index: ad_count, format: 'square' }
        ad_count += 1
      end
      
      # Add the actual item
      result << { type: 'meme', data: item }
    end
    
    result
  end
  
  # Get ad analytics tracking attributes
  def ad_tracking_attributes(ad_index)
    {
      'data-track-event': 'ad_impression',
      'data-ad-position': ad_index,
      'data-ad-frequency': ad_frequency
    }
  end
  
  # Check if ad blocker is detected (client-side)
  def ad_blocker_detection_script
    <<-HTML
      <script>
        // Ad blocker detection
        (function() {
          var adBlockDetected = false;
          var testAd = document.createElement('div');
          testAd.innerHTML = '&nbsp;';
          testAd.className = 'adsbox ad-placement ad-placeholder';
          testAd.style.position = 'absolute';
          testAd.style.left = '-9999px';
          document.body.appendChild(testAd);
          
          setTimeout(function() {
            if (testAd.offsetHeight === 0 || testAd.clientHeight === 0) {
              adBlockDetected = true;
              console.log('ℹ️ [ADS] Ad blocker detected');
              
              // Track for analytics
              if (window.activityTracker) {
                window.activityTracker.track('ad_blocker_detected');
              }
            }
            document.body.removeChild(testAd);
          }, 100);
        })();
      </script>
    HTML
  end
end
