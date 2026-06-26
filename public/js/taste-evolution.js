// ==================================================================
// TASTE EVOLUTION INTERACTIVE FEATURES
// ==================================================================
// Enhances taste evolution page with smooth animations and interactions

document.addEventListener('DOMContentLoaded', function() {
  initTasteEvolution();
});

function initTasteEvolution() {
  // Animate timeline on scroll
  observeTimeline();
  
  // Animate confidence bars
  animateConfidenceBars();
  
  // Add export functionality
  addExportButton();
}

function observeTimeline() {
  const timelineItems = document.querySelectorAll('.timeline-item');
  
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
      }
    });
  }, {
    threshold: 0.1
  });
  
  timelineItems.forEach(item => {
    observer.observe(item);
  });
}

function animateConfidenceBars() {
  const bars = document.querySelectorAll('.confidence-bar');
  
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const bar = entry.target;
        const width = bar.style.width;
        bar.style.width = '0%';
        setTimeout(() => {
          bar.style.width = width;
        }, 100);
        observer.unobserve(bar);
      }
    });
  });
  
  bars.forEach(bar => observer.observe(bar));
}

function addExportButton() {
  const header = document.querySelector('.page-header');
  if (!header) return;
  
  const exportBtn = document.createElement('button');
  exportBtn.className = 'btn-export';
  exportBtn.textContent = 'Export My Taste Profile';
  exportBtn.onclick = exportTasteProfile;
  
  header.appendChild(exportBtn);
}

function exportTasteProfile() {
  // Export taste evolution data as JSON
  const data = {
    exported_at: new Date().toISOString(),
    taste_evolution: window.tasteEvolutionData
  };
  
  const blob = new Blob([JSON.stringify(data, null, 2)], {type: 'application/json'});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'my-taste-profile.json';
  a.click();
  URL.revokeObjectURL(url);
}
