# A/B Testing Admin Routes
# Provides UI for managing and monitoring experiments

require 'sinatra/base'

module Routes
  class ABTesting < Sinatra::Base
    # Admin dashboard for A/B testing
    get '/admin/ab-testing' do
      halt 403, "Forbidden" unless is_admin?
      
      @experiments = ABTestingService.list_experiments
      erb :'admin/ab_testing'
    end
    
    # Create new experiment
    post '/admin/ab-testing/create' do
      halt 403, "Forbidden" unless is_admin?
      
      name = params[:name]
      description = params[:description]
      
      # Parse variants from form
      # Expected format: variant_name:weight,variant_name:weight
      variants = {}
      params[:variants].split(',').each do |pair|
        variant_name, weight = pair.split(':')
        variants[variant_name.strip] = weight.to_f
      end
      
      success = ABTestingService.create_experiment(
        name,
        description,
        variants,
        params[:active] == 'true'
      )
      
      if success
        flash[:success] = "Experiment created successfully!"
      else
        flash[:error] = "Failed to create experiment"
      end
      
      redirect '/admin/ab-testing'
    end
    
    # Toggle experiment active status
    post '/admin/ab-testing/:name/toggle' do
      halt 403, "Forbidden" unless is_admin?
      
      experiment_name = params[:name]
      active = params[:active] == 'true'
      
      success = ABTestingService.toggle_experiment(experiment_name, active)
      
      content_type :json
      { success: success }.to_json
    end
    
    # Get experiment statistics (API endpoint)
    get '/admin/ab-testing/:name/stats' do
      halt 403, "Forbidden" unless is_admin?
      
      experiment_name = params[:name]
      stats = ABTestingService.get_stats(experiment_name)
      
      content_type :json
      stats.to_json
    end
    
    # View experiment details
    get '/admin/ab-testing/:name' do
      halt 403, "Forbidden" unless is_admin?
      
      @experiment_name = params[:name]
      @stats = ABTestingService.get_stats(@experiment_name)
      
      erb :'admin/ab_testing_detail'
    end
    
    private
    
    def is_admin?
      session[:user_id] && User.find(session[:user_id])&.admin?
    rescue
      false
    end
  end
end
