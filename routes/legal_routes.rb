# frozen_string_literal: true

# Legal & Compliance Routes
# Provides routes for Privacy Policy, Terms of Service, About, Contact, and DMCA pages
# These pages are required for Google AdSense approval and general legal compliance

# Privacy Policy
get '/privacy' do
  erb :privacy
end

# Terms of Service
get '/terms' do
  erb :terms
end

# About Page
get '/about' do
  erb :about
end

# Contact Page
get '/contact' do
  erb :contact
end

# DMCA Copyright Policy
get '/dmca' do
  erb :dmca
end

# Alias routes for common variations
get '/tos' do
  redirect '/terms'
end

get '/terms-of-service' do
  redirect '/terms'
end

get '/privacy-policy' do
  redirect '/privacy'
end

get '/copyright' do
  redirect '/dmca'
end

get '/about-us' do
  redirect '/about'
end

get '/contact-us' do
  redirect '/contact'
end
