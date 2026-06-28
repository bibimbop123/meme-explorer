# frozen_string_literal: true
# config/constants.rb
#
# CONSOLIDATED: All constants live in config/app_constants.rb (AppConstants module).
# This file is kept only so existing require_relative constants callsites still work.
# MemeExplorerConstants is aliased to AppConstants at the bottom of app_constants.rb.
#
# DO NOT add or redefine any constants here — they will silently override AppConstants
# values because Ruby warns on constant redefinition but uses the last-set value.

require_relative "app_constants"

# MemeExplorerConstants is set at the bottom of app_constants.rb as:
#   MemeExplorerConstants = AppConstants unless defined?(MemeExplorerConstants)
# No further definitions needed in this file.
