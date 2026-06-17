# How to Display Content from Reddit Crossposts

**Date:** June 17, 2026  
**Status:** Implementation Guide

## Overview

This guide explains how to display Reddit crosspost content in your meme application. Currently, the app **filters out crossposts** to show only original content, but this guide will show you how to enable and display crosspost data when needed.

---

## Understanding Reddit Crosspost Data

When Reddit provides crosspost data, it includes:

### 1. **Crosspost Detection Fields**
```ruby
post_data['is_crosspost']              # Boolean - true if this is a crosspost
post_data['crosspost_parent']          # String - ID of original post (e.g., "t3_abc123")
post_data['crosspost_parent_list']     # Array - Full original post data
post_data['num_crossposts']            # Integer - How many times this has been crossposted
```

### 2. **Crosspost Parent Data**
The `crosspost_parent_list` contains the **full original post data**, including:
```ruby
original_post = post_data['crosspost_parent_list']&.first

# Original post details
original_post['subreddit']         # Where it was originally posted
original_post['author']            # Original author
original_post['title']             # Original title
original_post['url']               # Original image/media URL
original_post['permalink']         # Link to original post
original_post['ups']               # Upvotes on original
original_post['created_utc']       # When originally posted
original_post['is_gallery']        # If it's a gallery post
original_post['gallery_data']      # Gallery images
original_post['media_metadata']    # Media details
```

---

## Step 1: Enable Crossposts in Data Fetching

### Modify `lib/services/api_cache_service.rb`

Currently, crossposts are filtered out. To enable them:

#### Option A: Remove Filtering (Lines ~297, ~388)
```ruby
# BEFORE (current code - filters crossposts):
next if post_data['is_crosspost'] || post_data['crosspost_parent']

# AFTER (allow crossposts):
# Comment out or remove the line above
```

#### Option B: Make Filtering Configurable
```ruby
# Add at the top of the class
ALLOW_CROSSPOSTS = ENV.fetch('ALLOW_REDDIT_CROSSPOSTS', 'false') == 'true'

# Then in the fetching logic:
next if !ALLOW_CROSSPOSTS && (post_data['is_crosspost'] || post_data['crosspost_parent'])
```

---

## Step 2: Extract Crosspost Data in Parse Method

### Enhance `parse_reddit_response` in `RedditFetcherService`

Add crosspost data extraction after line 145:

```ruby
# Build meme object
meme = {
  "title" => post_data["title"],
  "url" => image_url,
  "subreddit" => post_data["subreddit"],
  "likes" => post_data["ups"] || 0,
  "permalink" => post_data["permalink"]
}

# Add crosspost metadata if present
if post_data["is_crosspost"] && post_data["crosspost_parent_list"]&.any?
  original = post_data["crosspost_parent_list"].first
  
  meme["is_crosspost"] = true
  meme["crosspost_data"] = {
    "original_subreddit" => original["subreddit"],
    "original_author" => original["author"],
    "original_title" => original["title"],
    "original_permalink" => original["permalink"],
    "original_ups" => original["ups"] || 0,
    "original_url" => original["url"],
    "crossposted_to" => post_data["subreddit"],
    "crosspost_by" => post_data["author"]
  }
  
  # Use original post's media if better quality
  if original["url"] && !original["is_video"]
    meme["url"] = original["url"]
  end
  
  # Handle gallery posts from original
  if original["is_gallery"] && original["media_metadata"]
    gallery_images = extract_gallery_images(original)
    if gallery_images && gallery_images.any?
      meme["is_gallery"] = true
      meme["gallery_images"] = gallery_images
    end
  end
end

# Add gallery data if present (existing code continues...)
```

---

## Step 3: Display Crossposts in Views

### Option A: Add Crosspost Badge (Simple)

In your meme display view (e.g., `views/meme_page.erb` or card partials):

```erb
<% if meme['is_crosspost'] %>
  <div class="crosspost-badge">
    <i class="fas fa-share"></i>
    Crossposted from r/<%= meme.dig('crosspost_data', 'original_subreddit') %>
  </div>
<% end %>
```

### Option B: Full Crosspost Attribution

Create a new partial: `views/_crosspost_info.erb`

```erb
<% if meme['is_crosspost'] && meme['crosspost_data'] %>
  <div class="crosspost-attribution">
    <div class="crosspost-header">
      <i class="fas fa-share-square"></i>
      <span class="crosspost-label">Crosspost</span>
    </div>
    
    <div class="crosspost-details">
      <div class="original-post">
        <strong>Originally posted in:</strong>
        <a href="https://reddit.com/r/<%= meme['crosspost_data']['original_subreddit'] %>" 
           target="_blank" 
           rel="noopener">
          r/<%= meme['crosspost_data']['original_subreddit'] %>
        </a>
      </div>
      
      <div class="original-author">
        <strong>by</strong> u/<%= meme['crosspost_data']['original_author'] %>
      </div>
      
      <% if meme['crosspost_data']['original_title'] != meme['title'] %>
        <div class="original-title">
          <strong>Original title:</strong>
          "<%= meme['crosspost_data']['original_title'] %>"
        </div>
      <% end %>
      
      <div class="crosspost-path">
        <small>
          Crossposted to r/<%= meme['crosspost_data']['crossposted_to'] %>
          <% if meme['crosspost_data']['crosspost_by'] %>
            by u/<%= meme['crosspost_data']['crosspost_by'] %>
          <% end %>
        </small>
      </div>
      
      <a href="https://reddit.com<%= meme['crosspost_data']['original_permalink'] %>" 
         target="_blank" 
         rel="noopener"
         class="view-original-btn">
        View Original Post
      </a>
    </div>
  </div>
<% end %>
```

### Option C: Inline Attribution (Compact)

```erb
<div class="meme-card">
  <img src="<%= meme['url'] %>" alt="<%= meme['title'] %>">
  
  <div class="meme-meta">
    <h3><%= meme['title'] %></h3>
    
    <% if meme['is_crosspost'] %>
      <p class="crosspost-info">
        <i class="fas fa-share"></i>
        From 
        <a href="https://reddit.com/r/<%= meme.dig('crosspost_data', 'original_subreddit') %>">
          r/<%= meme.dig('crosspost_data', 'original_subreddit') %>
        </a>
        → r/<%= meme['subreddit'] %>
      </p>
    <% else %>
      <p>r/<%= meme['subreddit'] %></p>
    <% end %>
  </div>
</div>
```

---

## Step 4: Add Styling for Crossposts

Create `public/css/crosspost.css`:

```css
/* Crosspost Badge */
.crosspost-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: #0079d3;
  color: white;
  padding: 4px 12px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
  margin-bottom: 8px;
}

.crosspost-badge i {
  font-size: 10px;
}

/* Full Attribution Block */
.crosspost-attribution {
  background: #f6f7f8;
  border-left: 3px solid #0079d3;
  padding: 12px;
  margin: 12px 0;
  border-radius: 4px;
}

.crosspost-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
  color: #0079d3;
  font-weight: 600;
}

.crosspost-details {
  font-size: 14px;
  line-height: 1.6;
}

.crosspost-details > div {
  margin: 4px 0;
}

.crosspost-details a {
  color: #0079d3;
  text-decoration: none;
  font-weight: 500;
}

.crosspost-details a:hover {
  text-decoration: underline;
}

.original-title {
  font-style: italic;
  color: #666;
  margin: 8px 0;
}

.crosspost-path {
  color: #888;
  margin-top: 8px;
  padding-top: 8px;
  border-top: 1px solid #ddd;
}

.view-original-btn {
  display: inline-block;
  margin-top: 8px;
  padding: 6px 12px;
  background: #0079d3;
  color: white !important;
  border-radius: 4px;
  text-decoration: none !important;
  font-size: 13px;
  font-weight: 500;
}

.view-original-btn:hover {
  background: #005fa3;
}

/* Inline Crosspost Info */
.crosspost-info {
  color: #666;
  font-size: 13px;
  display: flex;
  align-items: center;
  gap: 6px;
}

.crosspost-info i {
  color: #0079d3;
}

/* Dark Mode */
@media (prefers-color-scheme: dark) {
  .crosspost-attribution {
    background: #1a1a1b;
    border-left-color: #0079d3;
  }
  
  .crosspost-details {
    color: #d7dadc;
  }
  
  .original-title {
    color: #999;
  }
  
  .crosspost-path {
    color: #666;
    border-top-color: #333;
  }
}
```

---

## Step 5: Remove Crosspost Filters

### Update `lib/services/random_selector_service.rb`

Remove or comment out the crosspost filter (around line 88):

```ruby
# BEFORE (filters crossposts):
filtered_memes = filter_crossposts(filtered_memes)

# AFTER (allow crossposts):
# filtered_memes = filter_crossposts(filtered_memes)  # Commented out
```

And remove/comment the filter method (around line 663):

```ruby
# def filter_crossposts(memes)
#   memes.reject do |meme|
#     meme['is_crosspost'] || meme['crosspost_parent'] || meme['crosspost_parent_list']
#   end
# end
```

---

## Step 6: Smart Crosspost Handling (Advanced)

### Prefer Original Over Duplicate Crossposts

Create a service: `lib/services/crosspost_deduplication_service.rb`

```ruby
class CrosspostDeduplicationService
  # Remove duplicate crossposts, keeping only the original
  def self.deduplicate(memes)
    seen_originals = {}
    
    memes.reject do |meme|
      if meme['is_crosspost'] && meme['crosspost_data']
        original_id = meme['crosspost_data']['original_permalink']
        
        # If we've seen the original, skip this crosspost
        if seen_originals[original_id]
          true
        else
          # Mark this original as seen
          seen_originals[original_id] = true
          false
        end
      else
        # Not a crosspost, keep it
        original_id = meme['permalink']
        seen_originals[original_id] = true
        false
      end
    end
  end
  
  # Enrich crosspost with original subreddit in our list
  def self.prefer_original(memes, our_subreddits)
    memes.map do |meme|
      if meme['is_crosspost'] && meme['crosspost_data']
        original_sub = meme['crosspost_data']['original_subreddit']
        
        # If original subreddit is in our list, link to it
        if our_subreddits.include?(original_sub)
          meme['prefer_original'] = true
          meme['original_in_our_subs'] = true
        end
      end
      
      meme
    end
  end
end
```

Usage in your selection service:

```ruby
# After fetching memes
memes = CrosspostDeduplicationService.deduplicate(memes)
```

---

## Step 7: Environment Configuration

Add to `.env`:

```bash
# Crosspost Configuration
ALLOW_REDDIT_CROSSPOSTS=true          # Enable crosspost display
SHOW_CROSSPOST_ATTRIBUTION=true       # Show full attribution
DEDUPLICATE_CROSSPOSTS=true          # Remove duplicates (keep original)
```

---

## Use Cases for Displaying Crossposts

### ✅ **When to Show Crossposts:**

1. **Content Discovery**
   - Shows how memes spread across subreddits
   - Helps users discover related communities

2. **Complete Coverage**
   - User's favorite subreddit might only have crossposts
   - Ensures they see all content from subscribed subs

3. **Trending Analysis**
   - Crosspost count indicates virality
   - Helps identify trending content

4. **Attribution & Credit**
   - Shows original source and creator
   - Respects content provenance

### ❌ **When to Filter Crossposts (Current Behavior):**

1. **Reduce Duplication**
   - Same meme appears multiple times
   - Cleaner, less repetitive feed

2. **Original Content Focus**
   - Prioritize unique content
   - Better experience for power users

3. **Cache Efficiency**
   - Smaller dataset to manage
   - Faster load times

---

## Testing Crossposts

### 1. Find Crossposts in Reddit API

```bash
# Test with a subreddit known for crossposts
curl "https://www.reddit.com/r/memes/top.json?limit=10" \
  -H "User-Agent: MemeExplorer/1.0" | \
  jq '.data.children[] | select(.data.is_crosspost == true)'
```

### 2. Test in Rails Console

```ruby
# In your development environment
require_relative 'lib/services/reddit_fetcher_service'

fetcher = RedditFetcherService.new(auth_strategy: :static)
memes = fetcher.fetch_memes(['memes'], limit: 25)

# Find crossposts
crossposts = memes.select { |m| m['is_crosspost'] }
puts "Found #{crossposts.count} crossposts"

# Inspect crosspost data
crossposts.first.dig('crosspost_data')
```

---

## Quick Implementation Checklist

- [ ] Decide: Allow all crossposts, or make it configurable?
- [ ] Remove/comment crosspost filters in `api_cache_service.rb`
- [ ] Remove/comment crosspost filters in `random_selector_service.rb`
- [ ] Add crosspost data extraction to parse method
- [ ] Create crosspost display partial
- [ ] Add crosspost styling (CSS)
- [ ] Test with subreddits that have crossposts (r/memes, r/funny)
- [ ] Optional: Implement deduplication service
- [ ] Optional: Add user preference toggle
- [ ] Clear cache to see changes immediately

---

## Summary

**To display crossposts:**

1. **Remove filtering** in fetch services
2. **Extract crosspost metadata** from `crosspost_parent_list`
3. **Display attribution** in your views with badges/cards
4. **Style appropriately** to distinguish from originals
5. **Test thoroughly** with real Reddit data

**Current Status:** App filters crossposts for quality  
**To Enable:** Follow steps above and clear cache

Need help implementing? Check related files:
- `lib/services/reddit_fetcher_service.rb` - Data fetching
- `lib/services/api_cache_service.rb` - API integration
- `lib/services/random_selector_service.rb` - Selection logic
- `CROSSPOST_FILTER_IMPLEMENTATION.md` - Current filtering docs
