# A/B Testing Admin Routes
# Uses the standard Sinatra extension pattern (self.registered) so routes
# have full access to the parent app's session, helpers, and settings.
# Previously used `class ABTesting < Sinatra::Base` mounted via `use` which
# had no session access and crashed on flash[] (sinatra-flash not in Gemfile).

module Routes
  module ABTesting
    def self.registered(app)
      # Admin dashboard for A/B testing
      app.get '/admin/ab-testing' do
        halt 403, 'Forbidden' unless UserService.is_admin?(session[:user_id])
        @experiments = ABTestingService.list_experiments
        erb :'admin/ab_testing'
      end

      # Create new experiment
      # Expected variants format: "variant_a:0.5,variant_b:0.5"
      app.post '/admin/ab-testing/create' do
        halt 403, 'Forbidden' unless UserService.is_admin?(session[:user_id])
        name = params[:name].to_s.strip
        halt 400, 'Experiment name required' if name.empty?

        variants = {}
        params[:variants].to_s.split(',').each do |pair|
          variant_name, weight = pair.split(':')
          variants[variant_name.to_s.strip] = weight.to_f if variant_name
        end

        ABTestingService.create_experiment(
          name,
          params[:description],
          variants,
          params[:active] == 'true'
        )
        redirect '/admin/ab-testing?notice=created'
      end

      # Toggle experiment active status
      app.post '/admin/ab-testing/:name/toggle' do
        halt 403, 'Forbidden' unless UserService.is_admin?(session[:user_id])
        content_type :json
        success = ABTestingService.toggle_experiment(params[:name], params[:active] == 'true')
        { success: success }.to_json
      end

      # Get experiment statistics (API endpoint)
      app.get '/admin/ab-testing/:name/stats' do
        halt 403, 'Forbidden' unless UserService.is_admin?(session[:user_id])
        content_type :json
        ABTestingService.get_stats(params[:name]).to_json
      end

      # View experiment details
      app.get '/admin/ab-testing/:name' do
        halt 403, 'Forbidden' unless UserService.is_admin?(session[:user_id])
        @experiment_name = params[:name]
        @stats = ABTestingService.get_stats(@experiment_name)
        erb :'admin/ab_testing_detail'
      end
    end
  end
end
