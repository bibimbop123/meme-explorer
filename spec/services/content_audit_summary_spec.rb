require_relative '../spec_helper'
require_relative '../../scripts/summarize_content_audit'
require 'open3'
require 'tempfile'

RSpec.describe ContentAuditSummary do
  let(:row) do
    { 'id' => 1, 'session' => 'guest', 'device' => 'mobile', 'visible' => 'yes',
      'available' => 'yes', 'readable' => 'unknown', 'repeated_url' => 'no',
      'repeated_artwork' => 'unknown', 'source_age' => 'unknown' }
  end

  it 'keeps unknowns in explicit visible denominators and excludes unviewed selections' do
    unseen = row.merge('id' => 3, 'visible' => 'no')
    %w[available readable repeated_url repeated_artwork source_age].each { |key| unseen[key] = 'unknown' }
    report = described_class.summarize([row, row.merge('id' => 2, 'readable' => 'yes'), unseen])
    expect(report).to include(rows: 3, visible: 2, not_visible: 1, target_met: false)
    expect(report[:metrics]['readable']).to include('unknown' => 1, 'yes' => 1, 'denominator' => 2, 'yes_percent' => 50.0)
    expect(report[:source_age]['unknown']).to eq(2)
    expect(report[:device_mix]).to eq('mobile' => 2, 'desktop' => 0)
  end

  it 'does not invent percentages for empty observations' do
    expect(described_class.summarize([])[:metrics]['available']['yes_percent']).to be_nil
  end

  it 'rejects duplicate IDs, private extra fields and inconsistent observations' do
    [[row, row], [row.merge('email' => 'private@example.test')], [row.merge('visible' => 'no')],
     [row.merge('readable' => true)], [row.merge('source_age' => 'fresh')], nil].each do |rows|
      expect { described_class.summarize(rows) }.to raise_error(ArgumentError)
    end
  end

  it 'bounds rows and identifies completion by visible selections, not requests' do
    expect { described_class.summarize(Array.new(1001, row)) }.to raise_error(ArgumentError)
    report = described_class.summarize(100.times.map { |i| row.merge('id' => i + 1) })
    expect(report[:target_met]).to be true
  end

  it 'fails privately when CLI input cannot be read' do
    output, error, status = Open3.capture3(RbConfig.ruby,
      File.expand_path('../../scripts/summarize_content_audit.rb', __dir__), '/private/nonexistent-audit.json')
    expect(status.exitstatus).to eq(1)
    expect(output).to eq('')
    expect(error).to include('Input values and paths omitted')
    expect(error).not_to include('/private/nonexistent')
  end

  it 'detects missing joint sample cells even when both marginal mixes are present' do
    rows = 100.times.map do |i|
      row.merge('id' => i + 1, 'session' => i.even? ? 'guest' : 'returning',
        'device' => i.even? ? 'mobile' : 'desktop')
    end
    report = described_class.summarize(rows)
    expect(report[:target_met]).to be true
    checks = report[:collection_checks]
    expect(checks[:session_device_cells].map { |cell| cell[:count] }).to eq([50, 0, 0, 50])
    expect(checks[:warnings].join(' ')).to include('cells have no visible observations', 'judgments are unknown')
    expect(checks[:unknown_judgments]['readable']).to eq(100)
  end

  it 'keeps manual acceptance open even for fully judged observations in all cells' do
    rows = 100.times.map do |i|
      row.merge('id' => i + 1, 'session' => i % 4 < 2 ? 'guest' : 'returning',
        'device' => i.even? ? 'mobile' : 'desktop', 'readable' => 'yes',
        'repeated_artwork' => 'no', 'source_age' => 'under_day')
    end
    checks = described_class.summarize(rows)[:collection_checks]
    expect(checks[:session_device_cells].map { |cell| cell[:count] }).to eq([25, 25, 25, 25])
    expect(checks[:warnings]).to eq([])
    expect(checks[:requires_manual_review]).to include('Reviewer agreement', 'User tasks and subjective worth')
    expect(checks[:note]).to include('No automated research acceptance')
  end

  it 'does not count unviewed requests toward collection coverage or unknown judgments' do
    unseen = row.merge('visible' => 'no')
    %w[available readable repeated_url repeated_artwork source_age].each { |field| unseen[field] = 'unknown' }
    checks = described_class.summarize([unseen])[:collection_checks]
    expect(checks[:session_device_cells].sum { |cell| cell[:count] }).to eq(0)
    expect(checks[:unknown_judgments].values.sum).to eq(0)
    expect(checks[:warnings]).to include('Fewer than 100 visible observations.')
  end

  it 'runs the CLI successfully without exporting row identifiers' do
    Tempfile.create(['content-audit', '.json']) do |file|
      file.write([row].to_json)
      file.flush
      output, error, status = Open3.capture3(RbConfig.ruby,
        File.expand_path('../../scripts/summarize_content_audit.rb', __dir__), file.path)
      expect(status.exitstatus).to eq(0)
      expect(error).to eq('')
      report = JSON.parse(output)
      expect(report).to include('visible' => 1, 'target_met' => false)
      expect(report['device_mix']).to eq('mobile' => 1, 'desktop' => 0)
      expect(report).not_to have_key('id')
    end
  end

  it 'rejects malformed and oversized CLI files without echoing private input' do
    ['{"private-email":"secret@example.test"', 'x' * (described_class::MAX_BYTES + 1)].each do |input|
      Tempfile.create(['content-audit', '.json']) do |file|
        file.write(input)
        file.flush
        output, error, status = Open3.capture3(RbConfig.ruby,
          File.expand_path('../../scripts/summarize_content_audit.rb', __dir__), file.path)
        expect(status.exitstatus).to eq(1)
        expect(output).to eq('')
        expect(error).not_to include(file.path, 'secret@example.test')
      end
    end
  end
end