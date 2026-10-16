require_relative '../spec_helper'

RSpec.describe PersonalityContent do
  it 'selects supported messages and falls back for unknown errors' do
    expect(described_class::LOADING_MESSAGES).to include(described_class.random_loading_message)
    expect(described_class::NAV_HINTS).to include(described_class.random_nav_hint)
    expect(described_class::ERROR_MESSAGES[:general_error]).to include(described_class.random_error_message(:unknown))
  end

  it 'substitutes achievement context and handles unknown achievements' do
    expect(described_class.achievement_message(:unknown)).to eq('Nice!')
    allow(described_class::ACHIEVEMENT_MESSAGES[:level_up]).to receive(:sample).and_return('Level {LEVEL}')
    expect(described_class.achievement_message(:level_up, level: 12)).to eq('Level 12')
  end

  it 'provides time and progression messages at each boundary' do
    [0, 5, 12, 18, 22].each do |hour|
      allow(Time).to receive(:now).and_return(Time.utc(2026, 10, 15, hour))
      expect(described_class.time_greeting).not_to be_empty
    end
    [0, 1, 3, 7, 30].each { |days| expect(described_class.streak_encouragement(days)).not_to be_empty }
    [1, 6, 11, 21, 36, 51, 76].each { |level| expect(described_class.level_message(level)).not_to be_empty }
  end
end