/**
 * Particle Effects System for Meme Explorer
 * Creates visual celebrations for user actions
 * Created: May 10, 2026
 */

class ParticleSystem {
  constructor() {
    this.particles = [];
    this.animationFrameId = null;
    this.canvas = null;
    this.ctx = null;
    this.enabled = localStorage.getItem('particlesEnabled') !== 'false';
  }

  /**
   * Initialize particle canvas overlay
   */
  init() {
    if (this.canvas) return; // Already initialized

    this.canvas = document.createElement('canvas');
    this.canvas.id = 'particle-canvas';
    this.canvas.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      z-index: 9999;
    `;
    document.body.appendChild(this.canvas);

    this.ctx = this.canvas.getContext('2d');
    this.resize();

    window.addEventListener('resize', () => this.resize());
    console.log('✨ Particle system initialized');
  }

  /**
   * Resize canvas to window size
   */
  resize() {
    if (!this.canvas) return;
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
  }

  /**
   * Create particle burst at coordinates
   */
  burst(x, y, options = {}) {
    if (!this.enabled) return;
    if (!this.canvas) this.init();

    const defaults = {
      count: 20,
      colors: ['#ff6b6b', '#ff8a00', '#667eea', '#f093fb'],
      size: 8,
      speed: 5,
      gravity: 0.3,
      life: 60
    };

    const settings = { ...defaults, ...options };

    // Create particles
    for (let i = 0; i < settings.count; i++) {
      const angle = (Math.PI * 2 * i) / settings.count;
      const speed = settings.speed * (0.5 + Math.random() * 0.5);
      
      this.particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        color: settings.colors[Math.floor(Math.random() * settings.colors.length)],
        size: settings.size * (0.5 + Math.random() * 0.5),
        alpha: 1,
        life: settings.life,
        maxLife: settings.life,
        gravity: settings.gravity
      });
    }

    // Start animation loop if not already running
    if (!this.animationFrameId) {
      this.animate();
    }
  }

  /**
   * Create heart particles (for likes)
   */
  hearts(x, y, count = 10) {
    if (!this.enabled) return;
    if (!this.canvas) this.init();

    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 2 + Math.random() * 3;
      
      this.particles.push({
        x: x + (Math.random() - 0.5) * 40,
        y: y + (Math.random() - 0.5) * 40,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed - 2, // Upward bias
        type: 'heart',
        color: '#ff4458',
        size: 12 + Math.random() * 8,
        alpha: 1,
        life: 80,
        maxLife: 80,
        gravity: -0.1, // Float upward
        rotation: Math.random() * Math.PI * 2,
        rotationSpeed: (Math.random() - 0.5) * 0.2
      });
    }

    if (!this.animationFrameId) {
      this.animate();
    }
  }

  /**
   * Create star burst (for achievements/saves)
   */
  stars(x, y, count = 15) {
    if (!this.enabled) return;
    if (!this.canvas) this.init();

    const colors = ['#ffd700', '#ffed4e', '#fff700', '#ffc107'];

    for (let i = 0; i < count; i++) {
      const angle = (Math.PI * 2 * i) / count;
      const speed = 4 + Math.random() * 2;
      
      this.particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        type: 'star',
        color: colors[Math.floor(Math.random() * colors.length)],
        size: 10 + Math.random() * 6,
        alpha: 1,
        life: 70,
        maxLife: 70,
        gravity: 0.2,
        rotation: 0,
        rotationSpeed: (Math.random() - 0.5) * 0.3
      });
    }

    if (!this.animationFrameId) {
      this.animate();
    }
  }

  /**
   * Create confetti explosion (for level ups)
   */
  confetti(x, y, count = 50) {
    if (!this.enabled) return;
    if (!this.canvas) this.init();

    const colors = ['#ff6b6b', '#4ecdc4', '#45b7d1', '#f093fb', '#ffd93d', '#6bcf7f'];

    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 3 + Math.random() * 6;
      
      this.particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed - 3, // Strong upward
        type: 'confetti',
        color: colors[Math.floor(Math.random() * colors.length)],
        size: 6 + Math.random() * 4,
        alpha: 1,
        life: 100,
        maxLife: 100,
        gravity: 0.4,
        rotation: Math.random() * Math.PI * 2,
        rotationSpeed: (Math.random() - 0.5) * 0.4,
        width: 8 + Math.random() * 6,
        height: 3 + Math.random() * 3
      });
    }

    if (!this.animationFrameId) {
      this.animate();
    }
  }

  /**
   * Animation loop
   */
  animate() {
    if (!this.ctx || !this.canvas) return;

    // Clear canvas
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    // Update and draw particles
    this.particles = this.particles.filter(particle => {
      // Update physics
      particle.vy += particle.gravity;
      particle.x += particle.vx;
      particle.y += particle.vy;
      particle.vx *= 0.99; // Air resistance
      particle.vy *= 0.99;
      particle.life--;

      // Update rotation
      if (particle.rotation !== undefined) {
        particle.rotation += particle.rotationSpeed;
      }

      // Fade out
      particle.alpha = particle.life / particle.maxLife;

      // Draw particle
      this.ctx.save();
      this.ctx.globalAlpha = particle.alpha;
      this.ctx.translate(particle.x, particle.y);
      
      if (particle.rotation) {
        this.ctx.rotate(particle.rotation);
      }

      if (particle.type === 'heart') {
        this.drawHeart(particle);
      } else if (particle.type === 'star') {
        this.drawStar(particle);
      } else if (particle.type === 'confetti') {
        this.drawConfetti(particle);
      } else {
        this.drawCircle(particle);
      }

      this.ctx.restore();

      return particle.life > 0;
    });

    // Continue animation if particles exist
    if (this.particles.length > 0) {
      this.animationFrameId = requestAnimationFrame(() => this.animate());
    } else {
      this.animationFrameId = null;
    }
  }

  /**
   * Draw a circle particle
   */
  drawCircle(particle) {
    this.ctx.fillStyle = particle.color;
    this.ctx.beginPath();
    this.ctx.arc(0, 0, particle.size, 0, Math.PI * 2);
    this.ctx.fill();
  }

  /**
   * Draw a heart particle
   */
  drawHeart(particle) {
    const size = particle.size;
    this.ctx.fillStyle = particle.color;
    this.ctx.beginPath();
    
    // Heart shape
    this.ctx.moveTo(0, size / 4);
    this.ctx.bezierCurveTo(-size / 2, -size / 4, -size, size / 8, 0, size);
    this.ctx.bezierCurveTo(size, size / 8, size / 2, -size / 4, 0, size / 4);
    
    this.ctx.fill();
  }

  /**
   * Draw a star particle
   */
  drawStar(particle) {
    const size = particle.size;
    const spikes = 5;
    this.ctx.fillStyle = particle.color;
    this.ctx.beginPath();

    for (let i = 0; i < spikes * 2; i++) {
      const angle = (Math.PI / spikes) * i;
      const radius = i % 2 === 0 ? size : size / 2;
      const x = Math.cos(angle) * radius;
      const y = Math.sin(angle) * radius;
      
      if (i === 0) {
        this.ctx.moveTo(x, y);
      } else {
        this.ctx.lineTo(x, y);
      }
    }

    this.ctx.closePath();
    this.ctx.fill();
  }

  /**
   * Draw a confetti particle (rectangle)
   */
  drawConfetti(particle) {
    this.ctx.fillStyle = particle.color;
    const w = particle.width || particle.size;
    const h = particle.height || particle.size / 2;
    this.ctx.fillRect(-w / 2, -h / 2, w, h);
  }

  /**
   * Toggle particles on/off
   */
  toggle() {
    this.enabled = !this.enabled;
    localStorage.setItem('particlesEnabled', this.enabled);
    return this.enabled;
  }

  /**
   * Check if enabled
   */
  isEnabled() {
    return this.enabled;
  }
}

// Global particle system instance
window.particleSystem = new ParticleSystem();

console.log('✨ Particle effects loaded and ready');
