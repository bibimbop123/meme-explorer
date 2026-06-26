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
    DB[:meme_reactions].where(
      meme_id: meme_id,
      user_id: user_id,
      reaction_type: reaction_type
    ).delete
    
    # Add new reaction
    DB[:meme_reactions].insert(
      meme_id: meme_id,
      user_id: user_id,
      reaction_type: reaction_type,
      created_at: Time.now
    )
    
    # Update counter
    update_reaction_counts(meme_id)
    
    # Broadcast real-time update if WebSocket available
    broadcast_reaction_update(meme_id, reaction_type)
    
    { success: true, reaction: reaction_type }
  rescue StandardError => e
    AppLogger.error("Reaction error: #{e.message}")
    { error: 'Failed to add reaction' }
  end
  
  def self.remove_reaction(meme_id, user_id, reaction_type)
    DB[:meme_reactions].where(
      meme_id: meme_id,
      user_id: user_id,
      reaction_type: reaction_type
    ).delete
    
    update_reaction_counts(meme_id)
    broadcast_reaction_update(meme_id, reaction_type)
    
    { success: true }
  end
  
  def self.get_reactions(meme_id)
    counts = DB[:memes].where(id: meme_id).first
    return {} unless counts
    
    {
      laugh: counts[:reaction_laugh] || 0,
      wow: counts[:reaction_wow] || 0,
      cry: counts[:reaction_cry] || 0,
      fire: counts[:reaction_fire] || 0,
      dead: counts[:reaction_dead] || 0,
      total: (counts[:reaction_laugh] || 0) + 
             (counts[:reaction_wow] || 0) + 
             (counts[:reaction_cry] || 0) + 
             (counts[:reaction_fire] || 0) + 
             (counts[:reaction_dead] || 0)
    }
  end
  
  def self.get_user_reaction(meme_id, user_id)
    reaction = DB[:meme_reactions]
      .where(meme_id: meme_id, user_id: user_id)
      .first
    
    reaction ? reaction[:reaction_type] : nil
  end
  
  def self.trending_by_reaction(reaction_type, limit = 20)
    column = "reaction_#{reaction_type}".to_sym
    
    DB[:memes]
      .where { created_at > Time.now - 86400 } # Last 24 hours
      .order(Sequel.desc(column))
      .limit(limit)
      .all
  end
  
  private
  
  def self.update_reaction_counts(meme_id)
    REACTION_TYPES.keys.each do |type|
      count = DB[:meme_reactions]
        .where(meme_id: meme_id, reaction_type: type)
        .count
      
      column = "reaction_#{type}".to_sym
      DB[:memes].where(id: meme_id).update(column => count)
    end
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
