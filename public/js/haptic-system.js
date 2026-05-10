/**
 * Enhanced Haptic Feedback System for Meme Explorer
 * Provides tactile feedback on mobile devices
 * Created: May 10, 2026
 */

class HapticSystem {
  constructor() {
    this.supported = 'vibrate' in navigator;
    this.enabled = localStorage.getItem('hapticsEnabled') !== 'false';
  }

  /**
   * Haptic patterns for different interactions
   */
  patterns = {
    light: [10],
    medium: [30],
    heavy: [50],
    success: [30, 10, 30],
    error: [100, 50, 100],
    notification: [50, 30, 50, 30, 50],
    heartbeat: [50, 100, 50],
    burst: [20, 20, 20, 20, 20]
  };

  /**
   * Trigger haptic feedback
   */
  trigger(pattern = 'light') {
    if (!this.supported || !this.enabled) return;

    const vibrationPattern = this.patterns[pattern] || this.patterns.light;
    
    try {
      navigator.vibrate(vibrationPattern);
    } catch (error) {
      console.warn('Haptic feedback failed:', error);
    }
  }

  /**
   * Toggle haptics on/off
   */
  toggle() {
    this.enabled = !this.enabled;
    localStorage.setItem('hapticsEnabled', this.enabled);
    
    // Give feedback for the toggle action itself
    if (this.enabled) {
      this.trigger('success');
    }
    
    return this.enabled;
  }

  /**
   * Check if haptics are supported and enabled
   */
  isEnabled() {
    return this.supported && this.enabled;
  }

  /**
   * Check if haptics are supported by device
   */
  isSupported() {
    return this.supported;
  }
}

// Global haptic system instance
window.hapticSystem = new HapticSystem();

console.log(`📳 Haptic system loaded (${window.hapticSystem.isSupported() ? 'supported' : 'not supported'})`);
