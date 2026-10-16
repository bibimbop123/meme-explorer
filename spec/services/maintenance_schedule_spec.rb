require_relative '../spec_helper'
require 'yaml'

RSpec.describe 'Maintenance scheduler startup wiring' do
  it 'loads the configured maintenance schedule from the server startup callback' do
    startup = nil
    config = double
    allow(config).to receive(:redis=)
    allow(config).to receive(:on).with(:startup) { |&callback| startup = callback }
    allow(Sidekiq).to receive(:configure_server).and_yield(config)
    allow(Sidekiq).to receive(:configure_client).and_yield(config)
    schedule = nil
    allow(Sidekiq).to receive(:schedule=) { |value| schedule = value }
    scheduler = double
    allow(SidekiqScheduler::Scheduler).to receive(:instance).and_return(scheduler)
    expect(scheduler).to receive(:reload_schedule!).once

    load File.expand_path('../../config/initializers/sidekiq.rb', __dir__)
    expect(startup).to respond_to(:call)
    startup.call

    expect(schedule.fetch('meme_pool_maintenance')).to include(
      'cron' => '*/5 * * * *', 'class' => 'MemePoolMaintenanceWorker', 'queue' => 'default')
  end

  it 'references loaded executable workers on configured queues' do
    config = YAML.load_file(File.expand_path('../../config/sidekiq.yml', __dir__), aliases: true)
    config.fetch(:schedule).each_value do |entry|
      worker = Object.const_get(entry.fetch('class'))
      expect(worker.instance_methods).to include(:perform)
      queue = entry['queue'] || worker.get_sidekiq_options.fetch('queue').to_s
      expect(config.fetch(:queues)).to include(queue)
    end
  end
end