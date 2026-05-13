# SimpleCov Configuration for Meme Explorer
# Tracks test coverage and generates reports

SimpleCov.start do
  # Name of the app
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/db/'
  add_filter '/scripts/'
  add_filter '/vendor/'
  
  # Group coverage by type
  add_group 'Services', 'lib/services'
  add_group 'Helpers', 'lib/helpers'
  add_group 'Routes', 'routes'
  add_group 'Workers', 'app/workers'
  add_group 'Models', 'lib/models'
  add_group 'Middleware', 'lib/middleware'
  
  # Coverage thresholds
  minimum_coverage 40  # Start with 40%, aim for 80%
  minimum_coverage_by_file 20
  
  # Track branches (Ruby 2.5+)
  enable_coverage :branch
  
  # Output format
  formatter SimpleCov::Formatter::HTMLFormatter
  
  # Coverage directory
  coverage_dir 'coverage'
end
