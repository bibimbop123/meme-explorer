# frozen_string_literal: true
# CONSOLIDATED: All constants now live in config/app_constants.rb (AppConstants module).
# This file is kept as a thin alias so existing callsites (MemeExplorerConfig::X)
# continue to work without changes.
require_relative 'app_constants'

MemeExplorerConfig = AppConstants unless defined?(MemeExplorerConfig)

class ConfigurationError < StandardError; end
