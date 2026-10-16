require_relative '../spec_helper'

RSpec.describe 'Recipient ad eligibility' do
  let(:helper) { Object.new.extend(AdHelpers) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('DISABLE_ADS').and_return('false')
  end

  it 'excludes valid and invalid recipient paths' do
    ["/meme/#{'a' * 64}", '/meme/not-an-id'].each do |path|
      allow(helper).to receive(:request).and_return(double(path_info: path))
      expect(helper.should_show_ads?).to eq(false)
    end
  end

  it 'retains eligibility on ordinary random browsing' do
    allow(helper).to receive(:request).and_return(double(path_info: '/random'))
    expect(helper.should_show_ads?).to eq(true)
  end
end