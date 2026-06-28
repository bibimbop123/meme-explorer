# frozen_string_literal: true

# Reactions Service V2 - Multiple reaction types
class ReactionsService
  REACTION_TYPES = {
    'laugh' => '😂',
    'wow' => '😮',
    'cry' => '😭',
    'fire' => '🔥',
    'dead' => '💀'
  }.freeze
  
  def self.add_reaction(meme_id, user_id, reaction_type)
    return { error: 'Invalid reaction type' } unless REACTION_TYPES.key?(reaction_type)

    # Remove existing reaction of same type if exists
    DB.execute(
      "DELETE FROM meme_reactions WHERE meme_id = ? AND user_id = ? AND reaction_type = ?",
      [meme_id, user_id, reaction_type]
    )

    # Add new reaction
    DB.execute(
      "INSERT INTO meme_reactions (meme_id, user_id, reaction_type, created_at) VALUES (?, ?, ?, ?)",
      [meme_id, user_id, reaction_type, Time.now]
    )

    update_reaction_counts(meme_id)
    broadcast_reaction_update(meme_id, reaction_type)

    { success: true, reaction: reaction_type }
  rescue StandardError => e
    AppLogger.error("Reaction error: #{e.message}")
    { error: 'Failed to add reaction' }
  end

  def self.remove_reaction(meme_id, user_id, reaction_type)
    DB.execute(
      "DELETE FROM meme_reactions WHERE meme_id = ? AND user_id = ? AND reaction_type = ?",
      [meme_id, user_id, reaction_type]
    )
    update_reaction_counts(meme_id)
    broadcast_reaction_update(meme_id, reaction_type)
    { success: true }
  end

  def self.get_reactions(meme_id)
    counts = DB.execute(
      "SELECT reaction_laugh, reaction_wow, reaction_cry, reaction_fire, reaction_dead FROM memes WHERE id = ?",
      [meme_id]
    ).first
    return {} unless counts

    laugh = counts['reaction_laugh'].to_i
    wow   = counts['reaction_wow'].to_i
    cry   = counts['reaction_cry'].to_i
    fire  = counts['reaction_fire'].to_i
    dead  = counts['reaction_dead'].to_i
    {
      laugh: laugh, wow: wow, cry: cry, fire: fire, dead: dead,
      total: laugh + wow + cry + fire + dead
    }
  end

  def self.get_user_reaction(meme_id, user_id)
    reaction = DB.execute(
      "SELECT reaction_type FROM meme_reactions WHERE meme_id = ? AND user_id = ? LIMIT 1",
      [meme_id, user_id]
    ).first
    reaction ? reaction['reaction_type'] : nil
  end
  
  def self.trending_by_reaction(reaction_type, limit = 20)
    column = DB.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'memes' AND column_name = ?", ["reaction_#{reaction_type}"]).any? ? "reaction_#{reaction_type}" : "reaction_fire"
    DB.execute(
      "SELECT * FROM memes WHERE created_at > ? ORDER BY #{column} DESC LIMIT ?",
      [Time.now - 86400, limit]
    )
  rescue => e
    AppLogger.warn("trending_by_reaction failed: #{e.message}")
    []
  end
  
  private
  
  def self.update_reaction_counts(meme_id)
    REACTION_TYPES.keys.each do |type|
      count = DB.get_first_value(
        "SELECT COUNT(*) FROM meme_reactions WHERE meme_id = ? AND reaction_type = ?",
        [meme_id, type.to_s]
      ).to_i
      column = "reaction_#{type}"
      DB.execute(
        "UPDATE memes SET #{column} = ? WHERE id = ?",
        [count, meme_id]
      )
    end
  rescue => e
    AppLogger.warn("update_reaction_counts failed: #{e.message}")
  end
  
  def self.broadcast_reaction_update(meme_id, reaction_type)
    return unless defined?(RealtimeEventsService)
    
    reactions = get_reactions(meme_id)
    RealtimeEventsService.broadcast('reaction:update', {
      meme_id: meme_id,
      reaction_type: reaction_type,
      reactions: reactions
    })
  end
end
