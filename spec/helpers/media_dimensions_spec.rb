require_relative '../spec_helper'
require_relative '../../lib/helpers/media_dimensions'

RSpec.describe MediaDimensions do
  it 'retains validated source dimensions as integers' do
    expect(described_class.for('width' => '800', 'height' => 1600)).to eq(width: 800, height: 1600)
    expect(described_class.attributes('width' => 800, 'height' => 1600)).to include('width="800"', 'height="1600"')
  end

  it 'never invents dimensions or interpolates invalid input' do
    [nil, {}, { 'width' => 0, 'height' => 100 }, { 'width' => 999999, 'height' => 100 },
      { 'width' => '800" onload="bad', 'height' => 100 }].each do |data|
      expect(described_class.for(data)).to eq({})
      expect(described_class.attributes(data)).to eq('')
    end
  end
end