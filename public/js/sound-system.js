/**
 * Sound System for Meme Explorer
 * Provides audio feedback for user interactions
 * Created: May 10, 2026
 */

class SoundSystem {
  constructor() {
    this.sounds = {};
    this.muted = localStorage.getItem('soundMuted') === 'true';
    this.volume = parseFloat(localStorage.getItem('soundVolume') || '0.3');
    this.initialized = false;
  }

  /**
   * Initialize sound system with audio files
   */
  init() {
    if (this.initialized) return;
    
    // Define sound URLs - using free sound effects from freesound.org
    // Note: Replace with actual sound files when available
    this.soundDefinitions = {
      // Lightweight sounds using data URIs for instant loading
      like: { type: 'beep', frequency: 800, duration: 100 },
      save: { type: 'beep', frequency: 1200, duration: 150 },
      next: { type: 'beep', frequency: 600, duration: 80 },
      levelUp: { type: 'beep', frequency: 1500, duration: 300 },
      streak: { type: 'beep', frequency: 1000, duration: 200 },
      achievement: { type: 'beep', frequency: 1400, duration: 250 },
      error: { type: 'beep', frequency: 200, duration: 150 }
    };
    
    this.initialized = true;
    console.log('🔊 Sound system initialized');
  }

  /**
   * Play a sound using Web Audio API
   * More reliable and doesn't require external files
   */
  play(soundName) {
    if (this.muted || !this.initialized) return;
    
    const soundDef = this.soundDefinitions[soundName];
    if (!soundDef) {
      console.warn(`Sound "${soundName}" not found`);
      return;
    }

    try {
      // Create audio context if not exists
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
      }

      const ctx = this.audioContext;
      const oscillator = ctx.createOscillator();
      const gainNode = ctx.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(ctx.destination);

      oscillator.frequency.value = soundDef.frequency;
      oscillator.type = 'sine';

      // Envelope for smoother sound
      const now = ctx.currentTime;
      gainNode.gain.setValueAtTime(0, now);
      gainNode.gain.linearRampToValueAtTime(this.volume, now + 0.01);
      gainNode.gain.exponentialRampToValueAtTime(0.01, now + soundDef.duration / 1000);

      oscillator.start(now);
      oscillator.stop(now + soundDef.duration / 1000);
    } catch (error) {
      console.error('Error playing sound:', error);
    }
  }

  /**
   * Toggle mute state
   */
  toggleMute() {
    this.muted = !this.muted;
    localStorage.setItem('soundMuted', this.muted);
    console.log(`🔊 Sound ${this.muted ? 'muted' : 'unmuted'}`);
    return this.muted;
  }

  /**
   * Set volume (0.0 to 1.0)
   */
  setVolume(volume) {
    this.volume = Math.max(0, Math.min(1, volume));
    localStorage.setItem('soundVolume', this.volume);
  }

  /**
   * Check if muted
   */
  isMuted() {
    return this.muted;
  }
}

// Global sound system instance
window.soundSystem = new SoundSystem();

// Initialize on user interaction (required for Web Audio API)
document.addEventListener('click', () => {
  if (!window.soundSystem.initialized) {
    window.soundSystem.init();
  }
}, { once: true });

console.log('🎵 Sound system loaded and ready');
