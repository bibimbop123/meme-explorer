# frozen_string_literal: true

require_relative '../services/curator_notes_service'

# ============================================
# PHASE 4: CURATOR NOTES HELPER
# ============================================
# Helper methods to integrate curator notes into views

module CuratorNotesHelper
  # Get curator note for current meme
  def get_meme_curator_note(meme_data)
    @curator_service ||= CuratorNotesService.new
    @curator_service.get_curator_note(meme_data)
  end

  # Render curator note partial
  def render_curator_note(meme_data)
    curator_note = get_meme_curator_note(meme_data)
    erb :'_curator_note', locals: { curator_note: curator_note }
  end

  # Check if meme qualifies for curator note
  def has_curator_note?(meme_data)
    @curator_service ||= CuratorNotesService.new
    @curator_service.eligible_for_note?(meme_data)
  end
end
