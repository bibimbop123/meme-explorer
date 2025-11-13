# Clear existing data
Meme.delete_all

# Create sample memes with images from public/images
memes_data = [
  { title: "Funny Cat", category: "funny", image_url: "/images/funny1.jpeg", source_url: "reddit.com", view_count: 142 },
  { title: "Dank Meme", category: "dank", image_url: "/images/dank1.jpeg", source_url: "reddit.com", view_count: 245 },
  { title: "Wholesome Moment", category: "wholesome", image_url: "/images/wholesome1.jpeg", source_url: "reddit.com", view_count: 89 },
  { title: "Self Care Tips", category: "selfcare", image_url: "/images/selfcare1.jpeg", source_url: "reddit.com", view_count: 67 },
  { title: "Funny Dog Video", category: "funny", image_url: "/images/funny2.jpeg", source_url: "reddit.com", view_count: 321 },
  { title: "Dank Reaction", category: "dank", image_url: "/images/dank2.jpeg", source_url: "reddit.com", view_count: 198 },
  { title: "Wholesome Dance", category: "wholesome", image_url: "/images/wholesome2.jpeg", source_url: "reddit.com", view_count: 156 },
  { title: "Meditation Guide", category: "selfcare", image_url: "/images/selfcare2.jpeg", source_url: "reddit.com", view_count: 43 },
  { title: "Hilarious Jokes", category: "funny", image_url: "/images/funny3.jpeg", source_url: "reddit.com", view_count: 287 },
  { title: "Zen Moments", category: "selfcare", image_url: "/images/selfcare3.jpeg", source_url: "reddit.com", view_count: 76 },
  { title: "Family Love", category: "wholesome", image_url: "/images/wholesome2.jpeg", source_url: "reddit.com", view_count: 134 },
]

memes_data.each do |data|
  Meme.create!(data)
  puts "✓ Created meme: #{data[:title]}"
end

puts "✅ Database seeded with #{Meme.count} memes!"
