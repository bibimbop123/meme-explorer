# frozen_string_literal: true

# Legal & Compliance Routes
# Provides routes for Privacy Policy, Terms of Service, About, Contact, and DMCA pages
# These pages are required for Google AdSense approval and general legal compliance

class LegalRoutes
  def self.register(app)
    # Privacy Policy
    app.get '/privacy' do
      erb :privacy
    end

    # Terms of Service
    app.get '/terms' do
      erb :terms
    end

    # About Page
    app.get '/about' do
      erb :about
    end

    # Contact Page
    app.get '/contact' do
      erb :contact
    end

    # DMCA Copyright Policy
    app.get '/dmca' do
      erb :dmca
    end

    # Alias routes for common variations
    app.get '/tos' do
      redirect '/terms'
    end

    app.get '/terms-of-service' do
      redirect '/terms'
    end

    app.get '/privacy-policy' do
      redirect '/privacy'
    end

    app.get '/copyright' do
      redirect '/dmca'
    end

    app.get '/about-us' do
      redirect '/about'
    end

    app.get '/contact-us' do
      redirect '/contact'
    end
  end
end
