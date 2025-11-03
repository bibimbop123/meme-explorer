# Seasonal Content Service
# Manage seasonal placeholders and holiday special features
# Phase 3: Advanced Features - Part 3

class SeasonalContentService
  # Seasonal placeholder images
  SEASONAL_PLACEHOLDERS = {
    winter: {
      funny: '/images/seasonal/winter-funny.jpg',
      wholesome: '/images/seasonal/winter-wholesome.jpg',
      selfcare: '/images/seasonal/winter-selfcare.jpg',
      dank: '/images/seasonal/winter-dank.jpg'
    },
    spring: {
      funny: '/images/seasonal/spring-funny.jpg',
      wholesome: '/images/seasonal/spring-wholesome.jpg',
      selfcare: '/images/seasonal/spring-selfcare.jpg',
      dank: '/images/seasonal/spring-dank.jpg'
    },
    summer: {
      funny: '/images/seasonal/summer-funny.jpg',
      wholesome: '/images/seasonal/summer-wholesome.jpg',
      selfcare: '/images/seasonal/summer-selfcare.jpg',
      dank: '/images/seasonal/summer-dank.jpg'
    },
    fall: {
      funny: '/images/seasonal/fall-funny.jpg',
      wholesome: '/images/seasonal/fall-wholesome.jpg',
      selfcare: '/images/seasonal/fall-selfcare.jpg',
      dank: '/images/seasonal/fall-dank.jpg'
    }
  }.freeze

  # Holiday dates and configurations
  HOLIDAYS = {
    christmas: { month: 12, day: 25, header: '🎄 Holiday Trending Memes 🎄', season: :winter },
    new_year: { month: 1, day: 1, header: '🎉 New Year Trending Memes 🎉', season: :winter },
    halloween: { month: 10, day: 31, header: '👻 Spooky Trending Memes 👻', season: :fall },
    valentine: { month: 2, day: 14, header: '💕 Love & Laughter 💕', season: :spring },
    earth_day: { month: 4, day: 22, header: '🌍 Save the Planet Memes 🌍', season: :spring },
    summer_solstice: { month: 6, day: 21, header: '☀️ Summer Vibes ☀️', season: :summer }
  }.freeze

  # CSS color schemes by season
  SEASONAL_COLORS = {
    winter: {
      primary: '#b0e0e6',
      secondary: '#ffffff',
      accent: '#4169e1'
    },
    spring: {
      primary: '#d4f1d4',
      secondary: '#ffc0cb',
      accent: '#ff69b4'
    },
    summer: {
      primary: '#ffeb99',
      secondary: '#ffa500',
      accent: '#ff8c00'
    },
    fall: {
      primary: '#ff8c42',
      secondary: '#d2691e',
      accent: '#8b4513'
    }
  }.freeze

  class << self
    # Get current season
    # @return [Symbol] Season name (:winter, :spring, :summer, :fall)
    def current_season
      today = Date.today
      month = today.month

      case month
      when 12, 1, 2
        :winter
      when 3, 4, 5
        :spring
      when 6, 7, 8
        :summer
      when 9, 10, 11
        :fall
      end
    end

    # Get seasonal placeholder for category
    # @param category [String] Category name (funny, wholesome, selfcare, dank)
    # @return [String] Placeholder image URL
    def get_seasonal_placeholder(category)
      season = current_season
      placeholder = SEASONAL_PLACEHOLDERS[season]&.[](category.to_sym)
      placeholder || '/images/dank1.jpeg'  # Fallback
    end

    # Check if today is a special holiday
    # @return [Symbol] Holiday name or nil
    def current_holiday
      today = Date.today
      month = today.month
      day = today.day

      HOLIDAYS.each do |name, config|
        return name if config[:month] == month && config[:day] == day
      end

      nil
    end

    # Check if upcoming holiday (within 7 days)
    # @return [Symbol] Holiday name or nil
    def upcoming_holiday
      today = Date.today
      HOLIDAYS.each do |name, config|
        holiday = Date.new(today.year, config[:month], config[:day])
        days_until = (holiday - today).to_i
        return name if days_until.between?(0, 7)
      end

      nil
    end

    # Get special header for holiday
    # @param holiday [Symbol] Holiday name
    # @return [String] Special header text or nil
    def special_header_for_holiday(holiday)
      HOLIDAYS[holiday]&.dig(:header)
    end

    # Get seasonal colors
    # @return [Hash] Color palette for current season
    def seasonal_colors
      SEASONAL_COLORS[current_season]
    end

    # Get season-based theme configuration
    # @return [Hash] Complete theme config
    def season_theme
      season = current_season
      holiday = current_holiday

      {
        season:,
        colors: SEASONAL_COLORS[season],
        header: special_header_for_holiday(holiday),
        is_holiday: holiday.present?,
        holiday_name: holiday
      }
    end

    # Check if is holiday season (Dec 20 - Jan 2)
    # @return [Boolean]
    def is_holiday_season?
      today = Date.today
      month = today.month
      day = today.day

      (month == 12 && day >= 20) ||
        (month == 1 && day <= 2) ||
        (month == 10 && day >= 25)  # Halloween extended
    end
  end
end

# Usage:
#
# # Get current season
# SeasonalContentService.current_season
# # => :winter
#
# # Get seasonal placeholder
# SeasonalContentService.get_seasonal_placeholder('funny')
# # => "/images/seasonal/winter-funny.jpg"
#
# # Check for holiday
# SeasonalContentService.current_holiday
# # => :christmas
#
# # Get special header
# SeasonalContentService.special_header_for_holiday(:christmas)
# # => "🎄 Holiday Trending Memes 🎄"
#
# # Get seasonal colors
# colors = SeasonalContentService.seasonal_colors
# # => { primary: '#b0e0e6', secondary: '#ffffff', accent: '#4169e1' }
#
# # Get complete theme
# theme = SeasonalContentService.season_theme
# # => { season: :winter, colors: {...}, header: '🎄...', is_holiday: true, holiday_name: :christmas }
