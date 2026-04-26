# Personality & Humor Content for Meme Explorer
# Keep it fresh, funny, and on-brand
# Created: April 26, 2026

module PersonalityContent
  # ============================================
  # LOADING MESSAGES (Rotate randomly)
  # ============================================
  
  LOADING_MESSAGES = [
    "Summoning the dankest memes from the void...",
    "Negotiating with Reddit's meme overlords...",
    "Tattoo Annie is fetching your next laugh...",
    "Downloading comedy gold at 420 MB/s...",
    "Teaching algorithms what's funny (they're learning slowly)...",
    "Sorting memes by certified banger coefficient...",
    "Consulting with the Council of Dank...",
    "Bribing the internet for premium content...",
    "Loading pixels of pure joy...",
    "Waking up the meme hamsters...",
    "Calculating optimal giggle trajectory...",
    "Mining for digital gold...",
    "Asking the magic 8-ball for funny content...",
    "Recruiting chaos agents...",
    "Searching the multiverse for the perfect meme...",
    "Convincing memes to leave their natural habitat...",
    "Performing ancient meme rituals...",
    "Rolling for comedy criticals...",
    "Optimizing laugh-per-minute ratio...",
    "Activating giggle protocol...",
    "Compiling happiness into executable joy...",
    "Reverse-engineering viral content DNA...",
    "Buffering your daily dose of chaos...",
    "Establishing connection to the meme dimension...",
    "Translating internet culture to your eyeballs...",
  ].freeze
  
  # ============================================
  # ERROR MESSAGES (Make failures funny)
  # ============================================
  
  ERROR_MESSAGES = {
    image_failed: [
      "This meme went to get milk and never came back 🥛",
      "404: Meme not found. It's probably at a party we weren't invited to.",
      "This image is currently touching grass. Try again later 🌱",
      "Oops! This meme yeeted itself into the void.",
      "Error: Meme machine broke. We're fixing it with duct tape.",
      "This content is hiding. Have you tried saying 'pretty please'?",
      "The pixels got shy. Give them a moment.",
      "This meme called in sick today. Sending thoughts and prayers.",
      "Image.exe has stopped working. Classic Windows vibes.",
      "This content is currently being held hostage by slow internet.",
    ],
    api_failed: [
      "Reddit is being dramatic right now. Typical Monday energy.",
      "The internet hiccuped. It happens to the best of us.",
      "API said 'talk to the hand' 🤚",
      "Houston, we have a problem (the problem is we ran out of memes)",
      "Error 418: I'm a teapot (no seriously, check the HTTP code)",
      "The hamsters powering our servers need a snack break.",
      "Reddit took a quick nap. BRB in 3... 2... 1...",
      "The meme gods are testing our patience today.",
    ],
    general_error: [
      "Something went wrong. Probably user error. (Kidding! It's us.)",
      "Oops! Our bad. Tattoo Annie is investigating.",
      "Error: Success failed successfully.",
      "We messed up. But hey, at least you're not the one debugging this!",
      "¯\\_(ツ)_/¯ Technology, amirite?",
      "Plot twist: The error message is actually the meme.",
      "Task failed successfully. Wait, that's not right...",
      "Breaking news: Things broke. More at 11.",
    ]
  }.freeze
  
  # ============================================
  # NAVIGATION HINTS (Educational + Funny)
  # ============================================
  
  NAV_HINTS = [
    "Pro tip: Laughing burns 3 calories. You're basically exercising 🏋️",
    "Did you know? 87% of statistics are made up on the spot",
    "Current vibe: Seeking certified bangers only 🎵",
    "Warning: May cause uncontrollable giggling in public spaces",
    "Swipe like you're swiping right on happiness ❤️",
    "Press Space to unlock infinite scrolling powers ⚡",
    "Legend has it, the perfect meme is just 3 swipes away...",
    "Each meme viewed makes you 0.02% cooler. Science fact.",
    "You're here because TikTok got boring, aren't you?",
    "Welcome to procrastination headquarters 📋",
    "Remember to blink. You've been staring for 20 minutes.",
    "Hydration check! 💧 (We care about you)",
    "Your boss thinks you're working. We won't tell 🤐",
    "Achievement unlocked: Professional time-waster",
    "This is more addictive than bubble wrap, trust us",
    "If productivity was a meme, you'd be scrolling past it",
    "Fun fact: You can legally claim memes as therapy",
    "Careful, excessive laughter may result in abs. Maybe.",
    "This beats doomscrolling news. You're welcome.",
    "Your FBI agent is laughing with you right now 👁️",
    "Certified fresh content, no cap 🧢",
    "The algorithm thinks you're cool. Don't let it down.",
    "Meme calories don't count. We checked.",
    "You've been blessed by Tattoo Annie. Lucky you! ✨",
    "Current mood: Seeking chaos and finding it",
    "Plot twist: You're the main character now",
    "Side effects may include: improved mood, actual laughter",
    "Broccoli makes you Brolic! (But memes make you happy)",
    "Press T to toggle title visibility (you're welcome)",
    "Keyboard shortcuts are for power users. That's you! 💪",
  ].freeze
  
  # ============================================
  # ACHIEVEMENT MESSAGES (Celebrate milestones)
  # ============================================
  
  ACHIEVEMENT_MESSAGES = {
    first_meme: [
      "Welcome to the club! 🎉 Your life is about to get 47% funnier.",
      "First meme down! Only infinity left to go. Easy, right?",
      "And so it begins... RIP your productivity 📉",
    ],
    streak_3: [
      "3 days! You're basically committed now 🔥",
      "Day 3: The algorithm is learning your vibe...",
      "3-day streak! Your dedication to chaos is admirable.",
    ],
    streak_7: [
      "ONE WEEK STREAK! 🎊 You're officially addicted. Welcome home.",
      "7 days! That's like 3 months in internet time.",
      "Week 1 complete! Your meme game is STRONG 💪",
    ],
    streak_30: [
      "30 DAYS?! You're a legend. An absolute unit. A meme deity. 👑",
      "Month streak! At this point, we're basically family.",
      "30-day club! Your dedication is both inspiring and concerning.",
    ],
    level_up: [
      "LEVEL UP! 📈 Your meme expertise is showing.",
      "New level, new you! Time to update your LinkedIn.",
      "Congrats! You're now {LEVEL}% cooler than yesterday.",
      "Level {LEVEL} unlocked! Your mom would be proud. Probably.",
      "You leveled up! The grind never stops! 💪",
    ],
    saved_10: [
      "10 saved memes! Starting your own comedy museum? 🖼️",
      "You've saved 10 memes. Your taste is *chef's kiss* 👨‍🍳",
      "Meme collector achievement unlocked! 📚",
    ],
    liked_100: [
      "100 LIKES! You're basically a meme philanthropist at this point.",
      "Century club! Your positive vibes are contagious 🌟",
      "100 likes given! Spread that joy, you beautiful human.",
    ],
  }.freeze
  
  # ============================================
  # TIME-BASED GREETINGS
  # ============================================
  
  def self.time_greeting
    hour = Time.now.hour
    case hour
    when 0..4
      ["Still up? Respect. 🌙", "Late night energy is best energy", "The memes hit different at #{hour}AM", "Night owl mode: ACTIVATED 🦉"]
    when 5..11
      ["Good morning! ☕ Time to caffeinate and procrastinate", "Rise and grind (memes, not work)", "Morning scroll incoming...", "Breakfast of champions: Coffee + memes"]
    when 12..17
      ["Afternoon delight! 🌞", "Perfect time for a meme break", "Lunch break? Nah, meme break.", "Afternoon vibes: immaculate ✨"]
    when 18..21
      ["Evening vibes activated 🌆", "Time to unwind with quality content", "Dinner and a meme? Classic combo.", "Prime time for premium laughs"]
    else
      ["Prime meme hours! ✨", "The algorithm is extra spicy tonight", "Night owl mode: ACTIVATED 🦉", "After hours = peak comedy"]
    end.sample
  end
  
  # ============================================
  # DYNAMIC MESSAGES BASED ON USER STATE
  # ============================================
  
  def self.streak_encouragement(days)
    if days == 0
      "Start your streak today! Future you will thank present you."
    elsif days < 3
      "#{days} day#{days == 1 ? '' : 's'}! Keep it going! 🔥"
    elsif days < 7
      "#{days}-day streak! You're on FIRE! 🔥🔥"
    elsif days < 30
      "#{days} DAYS! You're unstoppable! 🚀"
    else
      "#{days} DAY LEGEND! Teach us your ways, master. 🙇"
    end
  end
  
  def self.level_message(level)
    case level
    when 1..5
      "Meme Novice vibes ✨"
    when 6..10
      "Casual Browser mode activated 📱"
    when 11..20
      "Meme Enthusiast status achieved! 🎯"
    when 21..35
      "Dank Specialist in the house! 💀"
    when 36..50
      "Meme Connoisseur extraordinaire! 🎩"
    when 51..75
      "VIRAL LEGEND! You're basically famous. 🌟"
    else
      "MEME GOD! We bow to your greatness. 👑"
    end
  end
  
  # ============================================
  # RANDOM HELPER METHODS
  # ============================================
  
  def self.random_loading_message
    LOADING_MESSAGES.sample
  end
  
  def self.random_error_message(type = :general_error)
    ERROR_MESSAGES[type]&.sample || ERROR_MESSAGES[:general_error].sample
  end
  
  def self.random_nav_hint
    NAV_HINTS.sample
  end
  
  def self.achievement_message(type, context = {})
    messages = ACHIEVEMENT_MESSAGES[type] || ["Nice!"]
    message = messages.sample
    
    # Replace placeholders
    message = message.gsub('{LEVEL}', context[:level].to_s) if context[:level]
    message
  end
end
