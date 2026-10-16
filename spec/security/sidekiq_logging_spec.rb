require_relative '../spec_helper'

RSpec.describe 'Sidekiq startup logging' do
  it 'does not print the Redis connection URL during initialization' do
    path = File.expand_path('../../config/initializers/sidekiq.rb', __dir__)
    expect { load path }.to output("✅ Sidekiq configured (Redis connection details omitted)\n").to_stdout
  end
end