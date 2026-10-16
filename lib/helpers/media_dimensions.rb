# frozen_string_literal: true

module MediaDimensions
  def self.for(data)
    return {} unless data.is_a?(Hash)
    width, height = data.values_at('width', 'height')
    return {} unless [width, height].all? { |value| value.to_s.match?(/\A[1-9]\d{0,4}\z/) && value.to_i <= 30000 }
    { width: width.to_i, height: height.to_i }
  end

  def self.attributes(data)
    dimensions = self.for(data)
    dimensions.empty? ? '' : "width=\"#{dimensions[:width]}\" height=\"#{dimensions[:height]}\""
  end
end