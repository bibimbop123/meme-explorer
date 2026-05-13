# FactoryBot Factories for Meme Explorer
# Used to create test data quickly and consistently

require 'factory_bot'
require 'faker'

FactoryBot.define do
  # Meme factory - creates realistic meme data for testing
  factory :meme, class: Hash do
    skip_create # Memes are hashes, not database records
    
    sequence(:url) { |n| "https://i.redd.it/test_meme_#{n}.jpg" }
    title { Faker::Lorem.sentence(word_count: 5) }
    subreddit { ['memes', 'dankmemes', 'meirl', 'funny', 'wholesomememes'].sample }
    likes { rand(10..10000) }
    views { rand(100..50000) }
    permalink { "/r/#{subreddit}/comments/abc123/#{title.parameterize}" }
    upvote_ratio { rand(0.7..0.99).round(2) }
    created_utc { Time.now.to_i - rand(0..86400) }
    
    # Computed fields
    comments { rand(0..500) }
    score { likes }
    
    # Media quality indicators
    media_quality_score { rand(0.6..1.0).round(2) }
    is_video { false }
    is_gif { [true, false].sample }
    
    # Humor type classification
    humor_type { ['absurdist', 'relatable', 'dank', 'wholesome', 'dark', 'meta'].sample }
    
    # Initialize as hash
    initialize_with { attributes.stringify_keys }
    
    # Traits for different meme types
    trait :high_quality do
      media_quality_score { rand(0.9..1.0).round(2) }
      likes { rand(1000..50000) }
      views { rand(10000..100000) }
      upvote_ratio { rand(0.9..0.99).round(2) }
    end
    
    trait :low_quality do
      media_quality_score { rand(0.3..0.6).round(2) }
      likes { rand(0..50) }
      views { rand(10..500) }
      upvote_ratio { rand(0.4..0.7).round(2) }
    end
    
    trait :trending do
      likes { rand(5000..100000) }
      views { rand(50000..500000) }
      comments { rand(100..2000) }
      created_utc { Time.now.to_i - rand(0..3600) } # Recent
      upvote_ratio { rand(0.85..0.99).round(2) }
    end
    
    trait :viral do
      likes { rand(50000..500000) }
      views { rand(500000..5000000) }
      comments { rand(1000..10000) }
      upvote_ratio { rand(0.95..0.99).round(2) }
    end
    
    trait :fresh do
      created_utc { Time.now.to_i - rand(0..7200) } # Within 2 hours
      likes { rand(100..1000) }
      views { rand(500..5000) }
    end
    
    trait :old do
      created_utc { Time.now.to_i - rand(604800..2592000) } # 1 week to 1 month
    end
    
    trait :video do
      is_video { true }
      is_gif { false }
      url { sequence(:url) { |n| "https://v.redd.it/test_video_#{n}" } }
    end
    
    trait :gif do
      is_video { false }
      is_gif { true }
      url { sequence(:url) { |n| "https://i.redd.it/test_gif_#{n}.gif" } }
    end
    
    trait :static_image do
      is_video { false }
      is_gif { false }
      url { sequence(:url) { |n| "https://i.redd.it/test_static_#{n}.jpg" } }
    end
    
    # Subreddit-specific traits
    trait :dankmemes do
      subreddit { 'dankmemes' }
      humor_type { ['dank', 'meta', 'absurdist'].sample }
    end
    
    trait :wholesome do
      subreddit { 'wholesomememes' }
      humor_type { 'wholesome' }
      title { "This made me smile today" }
    end
    
    trait :meirl do
      subreddit { 'meirl' }
      humor_type { 'relatable' }
      title { "Me in real life" }
    end
    
    # Local meme (from data/memes.yml)
    trait :local do
      url { nil }
      file { "/images/funny#{rand(1..10)}.jpeg" }
      permalink { nil }
    end
    
    # Broken/invalid meme
    trait :invalid do
      url { "https://broken.com/404.jpg" }
      media_quality_score { 0.0 }
    end
  end
  
  # User factory
  factory :user do
    sequence(:email) { |n| "user#{n}@test.com" }
    password_hash { BCrypt::Password.create('password123') }
    role { 'user' }
    created_at { Time.now }
    
    trait :admin do
      role { 'admin' }
    end
    
    trait :with_stats do
      after(:create) do |user|
        DB.execute(
          "INSERT INTO user_stats (user_id, xp, level, current_streak) VALUES (?, ?, ?, ?)",
          [user[:id], 100, 1, 0]
        )
      end
    end
  end
  
  # Meme stats factory (database record)
  factory :meme_stat do
    skip_create
    
    url { "https://i.redd.it/test#{rand(1000..9999)}.jpg" }
    title { Faker::Lorem.sentence }
    subreddit { 'memes' }
    likes { rand(0..1000) }
    views { rand(10..5000) }
    
    initialize_with do
      DB.execute(
        "INSERT INTO meme_stats (url, title, subreddit, likes, views, updated_at) 
         VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP) 
         RETURNING *",
        [url, title, subreddit, likes, views]
      ).first
    end
    
    trait :trending do
      likes { rand(1000..10000) }
      views { rand(5000..50000) }
    end
  end
end

# Helper methods for tests
module MemeTestHelpers
  def create_meme_pool(count = 10, **options)
    FactoryBot.build_list(:meme, count, **options)
  end
  
  def create_high_quality_pool(count = 5)
    FactoryBot.build_list(:meme, count, :high_quality)
  end
  
  def create_mixed_quality_pool(count = 20)
    high = FactoryBot.build_list(:meme, count / 2, :high_quality)
    low = FactoryBot.build_list(:meme, count / 4, :low_quality)
    normal = FactoryBot.build_list(:meme, count / 4)
    (high + low + normal).shuffle
  end
  
  def create_trending_pool(count = 10)
    FactoryBot.build_list(:meme, count, :trending)
  end
end

# Include helpers in RSpec
RSpec.configure do |config|
  config.include MemeTestHelpers
end
