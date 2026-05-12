/**
 * Leaderboard Interactive Features
 * Handles dynamic updates, AJAX loading, and smooth transitions
 * Created: May 10, 2026
 */

(function() {
  'use strict';

  // ============================================
  // STATE MANAGEMENT
  // ============================================
  
  const state = {
    currentType: 'weekly',
    currentPeriod: null,
    currentPage: 0,
    limit: 25,
    loading: false,
    userRank: null,
    nearby: [],
    challenge: null,
    userId: null,  // Track user authentication state
    isLoggedIn: false  // Track if user is logged in
  };

  // ============================================
  // DOM ELEMENTS
  // ============================================
  
  const elements = {
    typeButtons: null,
    periodSelect: null,
    leaderboardList: null,
    loadMoreBtn: null,
    userRankCard: null,
    nearbySection: null,
    loadingIndicator: null
  };

  // ============================================
  // INITIALIZATION
  // ============================================
  
  function init() {
    // Initialize user state from server data
    initializeUserState();
    
    // Cache DOM elements
    cacheElements();
    
    // Set up event listeners
    setupEventListeners();
    
    // Check for URL parameters
    checkURLParams();
    
    // Start auto-refresh
    startAutoRefresh();
    
    console.log('✅ Leaderboard.js initialized', {
      isLoggedIn: state.isLoggedIn,
      userId: state.userId
    });
  }
  
  function initializeUserState() {
    // Get user state from server-provided data
    if (window.LEADERBOARD_DATA) {
      state.userId = window.LEADERBOARD_DATA.userId;
      state.isLoggedIn = Boolean(state.userId);
      state.currentType = window.LEADERBOARD_DATA.type || 'weekly';
      state.currentPeriod = window.LEADERBOARD_DATA.period || null;
    } else {
      // Default to logged out
      state.userId = null;
      state.isLoggedIn = false;
    }
  }

  function cacheElements() {
    elements.typeButtons = document.querySelectorAll('.leaderboard-type-btn');
    elements.periodSelect = document.getElementById('period-select');
    elements.leaderboardList = document.getElementById('leaderboard-list');
    elements.loadMoreBtn = document.getElementById('load-more-btn');
    elements.userRankCard = document.getElementById('user-rank-card');
    elements.nearbySection = document.getElementById('nearby-competitors');
    elements.loadingIndicator = document.getElementById('loading-indicator');
  }

  function setupEventListeners() {
    // Type selection buttons
    if (elements.typeButtons) {
      elements.typeButtons.forEach(btn => {
        btn.addEventListener('click', handleTypeChange);
      });
    }

    // Period selection
    if (elements.periodSelect) {
      elements.periodSelect.addEventListener('change', handlePeriodChange);
    }

    // Load more button
    if (elements.loadMoreBtn) {
      elements.loadMoreBtn.addEventListener('click', loadMore);
    }

    // Refresh button
    const refreshBtn = document.getElementById('refresh-btn');
    if (refreshBtn) {
      refreshBtn.addEventListener('click', () => {
        showNotification('🔄 Refreshing leaderboard...', 'info');
        refreshLeaderboard();
      });
    }

    // Share buttons
    document.querySelectorAll('.share-rank-btn').forEach(btn => {
      btn.addEventListener('click', shareRank);
    });
  }

  function checkURLParams() {
    const params = new URLSearchParams(window.location.search);
    const type = params.get('type');
    const period = params.get('period');
    
    if (type) {
      state.currentType = type;
      updateActiveTypeButton();
    }
    
    if (period) {
      state.currentPeriod = period;
      if (elements.periodSelect) {
        elements.periodSelect.value = period;
      }
    }
  }

  // ============================================
  // TYPE & PERIOD CHANGES
  // ============================================
  
  function handleTypeChange(e) {
    e.preventDefault();
    const type = e.currentTarget.dataset.type;
    
    if (type === state.currentType) return;
    
    state.currentType = type;
    state.currentPage = 0;
    
    updateActiveTypeButton();
    updateURL();
    refreshLeaderboard();
  }

  function handlePeriodChange(e) {
    const period = e.target.value;
    state.currentPeriod = period || null;
    state.currentPage = 0;
    
    updateURL();
    refreshLeaderboard();
  }

  function updateActiveTypeButton() {
    if (!elements.typeButtons) return;
    
    elements.typeButtons.forEach(btn => {
      if (btn.dataset.type === state.currentType) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });
  }

  function updateURL() {
    const params = new URLSearchParams();
    params.set('type', state.currentType);
    if (state.currentPeriod) {
      params.set('period', state.currentPeriod);
    }
    
    const newURL = `${window.location.pathname}?${params.toString()}`;
    window.history.replaceState({}, '', newURL);
  }

  // ============================================
  // DATA FETCHING
  // ============================================
  
  async function refreshLeaderboard() {
    if (state.loading) return;
    
    state.loading = true;
    showLoading();
    
    try {
      const data = await fetchLeaderboardData();
      
      if (data.success) {
        renderLeaderboard(data.leaderboard);
        
        if (data.user_rank) {
          renderUserRank(data.user_rank, data.rank_change);
        }
        
        if (data.nearby) {
          renderNearbyCompetitors(data.nearby);
        }
        
        if (data.insights) {
          renderInsights(data.insights);
        }
        
        if (data.challenge) {
          updateChallengeProgress(data.challenge);
        }
      } else {
        showError(data.error || 'Failed to load leaderboard');
      }
    } catch (error) {
      console.error('Error fetching leaderboard:', error);
      showError('Network error. Please try again.');
    } finally {
      state.loading = false;
      hideLoading();
    }
  }

  async function fetchLeaderboardData() {
    const params = new URLSearchParams({
      type: state.currentType,
      limit: state.limit,
      offset: state.currentPage * state.limit
    });
    
    if (state.currentPeriod) {
      params.set('period', state.currentPeriod);
    }
    
    const response = await fetch(`/api/leaderboard?${params.toString()}`);
    return await response.json();
  }

  async function loadMore() {
    if (state.loading) return;
    
    state.currentPage++;
    state.loading = true;
    
    if (elements.loadMoreBtn) {
      elements.loadMoreBtn.disabled = true;
      elements.loadMoreBtn.textContent = 'Loading...';
    }
    
    try {
      const data = await fetchLeaderboardData();
      
      if (data.success && data.leaderboard.length > 0) {
        appendLeaderboard(data.leaderboard);
        
        if (data.leaderboard.length < state.limit) {
          hideLoadMoreButton();
        }
      } else {
        hideLoadMoreButton();
        showNotification('No more results', 'info');
      }
    } catch (error) {
      console.error('Error loading more:', error);
      showError('Failed to load more results');
      state.currentPage--;
    } finally {
      state.loading = false;
      if (elements.loadMoreBtn) {
        elements.loadMoreBtn.disabled = false;
        elements.loadMoreBtn.textContent = 'Load More';
      }
    }
  }

  // ============================================
  // RENDERING FUNCTIONS
  // ============================================
  
  function renderLeaderboard(entries) {
    if (!elements.leaderboardList) return;
    
    // Clear existing entries
    elements.leaderboardList.innerHTML = '';
    
    if (!entries || entries.length === 0) {
      renderEmptyState();
      return;
    }
    
    entries.forEach((entry, index) => {
      const entryEl = createLeaderboardEntry(entry, state.currentPage * state.limit + index);
      elements.leaderboardList.appendChild(entryEl);
    });
    
    // Show load more button if we got full page
    if (entries.length === state.limit) {
      showLoadMoreButton();
    } else {
      hideLoadMoreButton();
    }
  }

  function appendLeaderboard(entries) {
    if (!elements.leaderboardList || !entries) return;
    
    entries.forEach((entry, index) => {
      const entryEl = createLeaderboardEntry(entry, state.currentPage * state.limit + index);
      elements.leaderboardList.appendChild(entryEl);
    });
  }

  function createLeaderboardEntry(entry, index) {
    const div = document.createElement('div');
    const rank = entry.rank || (index + 1);
    // Check if this is the current user (only if logged in)
    const isCurrentUser = state.isLoggedIn && entry.is_current_user;
    
    // Determine entry classes
    let entryClasses = ['leaderboard-entry'];
    if (rank <= 3) {
      entryClasses.push('leaderboard-entry--podium');
      entryClasses.push(`leaderboard-entry--top${rank}`);
    }
    if (isCurrentUser) {
      entryClasses.push('leaderboard-entry--current-user');
    }
    
    div.className = entryClasses.join(' ');
    div.setAttribute('data-user-id', entry.user_id);
    div.setAttribute('data-rank', rank);
    
    // Rank display
    let rankDisplay;
    if (rank === 1) rankDisplay = '<span class="leaderboard-entry__rank leaderboard-entry__rank--medal">🥇</span>';
    else if (rank === 2) rankDisplay = '<span class="leaderboard-entry__rank leaderboard-entry__rank--medal">🥈</span>';
    else if (rank === 3) rankDisplay = '<span class="leaderboard-entry__rank leaderboard-entry__rank--medal">🥉</span>';
    else rankDisplay = `<div class="leaderboard-entry__rank">#${rank}</div>`;
    
    // Username
    const username = entry.reddit_username || entry.email?.split('@')[0] || `User #${entry.user_id}`;
    
    // Stats
    const level = entry.level || 1;
    const totalXP = entry.total_xp || entry.score || 0;
    const streak = entry.current_streak || entry.streak || '';
    
    div.innerHTML = `
      ${rankDisplay}
      <div class="leaderboard-entry__info">
        <div class="leaderboard-entry__username">
          ${escapeHtml(username)}
          ${isCurrentUser ? '<span style="color: var(--leaderboard-accent); margin-left: 0.5rem;">👋 You</span>' : ''}
        </div>
        <div class="leaderboard-entry__stats">
          <span class="leaderboard-entry__stat">⭐ Level ${level}</span>
          <span class="leaderboard-entry__stat">🔥 ${totalXP} XP</span>
          ${streak ? `<span class="leaderboard-entry__stat">📅 ${streak} day streak</span>` : ''}
        </div>
      </div>
      <div class="leaderboard-entry__score-container">
        <div class="leaderboard-entry__score">${entry.score || 0}</div>
        <div class="leaderboard-entry__score-label">points</div>
      </div>
    `;
    
    return div;
  }

  function renderUserRank(userRank, rankChange) {
    if (!elements.userRankCard) return;
    
    let changeHTML = '';
    if (rankChange && rankChange.change !== null) {
      const change = Math.abs(rankChange.change);
      let changeClass = 'rank-change--same';
      let changeIcon = '−';
      
      if (rankChange.direction === 'up') {
        changeClass = 'rank-change--up';
        changeIcon = '↑';
      } else if (rankChange.direction === 'down') {
        changeClass = 'rank-change--down';
        changeIcon = '↓';
      }
      
      if (change > 0) {
        changeHTML = `<span class="rank-change ${changeClass}">${changeIcon}${change}</span>`;
      }
    }
    
    elements.userRankCard.innerHTML = `
      <h3 class="user-rank-card__title">Your Rank</h3>
      <div class="user-rank-card__rank">#${userRank.rank} ${changeHTML}</div>
      <div class="user-rank-card__stats">
        <span class="user-rank-card__stat">⭐ Level ${userRank.level || 1}</span>
        <span class="user-rank-card__stat">🔥 ${userRank.total_xp || userRank.score || 0} XP</span>
        <span class="user-rank-card__stat">💪 ${userRank.score || 0} points this ${state.currentType === 'weekly' ? 'week' : 'month'}</span>
      </div>
    `;
    
    elements.userRankCard.style.display = 'block';
  }

  function renderNearbyCompetitors(nearby) {
    if (!elements.nearbySection || !nearby || nearby.length === 0) {
      if (elements.nearbySection) {
        elements.nearbySection.style.display = 'none';
      }
      return;
    }
    
    const list = elements.nearbySection.querySelector('.leaderboard-list');
    if (!list) return;
    
    list.innerHTML = '';
    nearby.forEach((entry, index) => {
      const entryEl = createLeaderboardEntry(entry, 0);
      list.appendChild(entryEl);
    });
    
    elements.nearbySection.style.display = 'block';
  }

  function renderInsights(insights) {
    const insightsEl = document.getElementById('leaderboard-insights');
    if (!insightsEl || !insights) return;
    
    const list = insightsEl.querySelector('.leaderboard-insights__list');
    if (!list) return;
    
    list.innerHTML = '';
    
    if (insights.gap_to_top10) {
      const li = document.createElement('li');
      li.className = 'leaderboard-insights__item';
      li.innerHTML = `
        <span class="leaderboard-insights__icon">🎯</span>
        <span>You need ${insights.gap_to_top10} more points to reach the top 10!</span>
      `;
      list.appendChild(li);
    }
    
    if (insights.percentile) {
      const li = document.createElement('li');
      li.className = 'leaderboard-insights__item';
      li.innerHTML = `
        <span class="leaderboard-insights__icon">📊</span>
        <span>You're in the top ${insights.percentile}% of all users!</span>
      `;
      list.appendChild(li);
    }
    
    if (insights.rank_improvement) {
      const li = document.createElement('li');
      li.className = 'leaderboard-insights__item';
      li.innerHTML = `
        <span class="leaderboard-insights__icon">📈</span>
        <span>${insights.rank_improvement}</span>
      `;
      list.appendChild(li);
    }
    
    insightsEl.style.display = list.children.length > 0 ? 'block' : 'none';
  }

  function renderEmptyState() {
    if (!elements.leaderboardList) return;
    
    elements.leaderboardList.innerHTML = `
      <div class="leaderboard-empty">
        <div class="leaderboard-empty__icon">🏆</div>
        <h3 class="leaderboard-empty__title">No Rankings Yet</h3>
        <p class="leaderboard-empty__message">Be the first to climb the leaderboard!</p>
      </div>
    `;
  }

  function updateChallengeProgress(challenge) {
    const progressBar = document.querySelector('.challenge-progress__bar');
    if (!progressBar || !challenge.progress) return;
    
    const percentage = Math.min(100, (challenge.progress.current / challenge.progress.required) * 100);
    progressBar.style.width = `${percentage}%`;
    progressBar.textContent = `${Math.round(percentage)}%`;
  }

  // ============================================
  // UI HELPERS
  // ============================================
  
  function showLoading() {
    if (elements.loadingIndicator) {
      elements.loadingIndicator.style.display = 'block';
    }
    if (elements.leaderboardList) {
      elements.leaderboardList.style.opacity = '0.5';
    }
  }

  function hideLoading() {
    if (elements.loadingIndicator) {
      elements.loadingIndicator.style.display = 'none';
    }
    if (elements.leaderboardList) {
      elements.leaderboardList.style.opacity = '1';
    }
  }

  function showLoadMoreButton() {
    if (elements.loadMoreBtn) {
      elements.loadMoreBtn.style.display = 'block';
    }
  }

  function hideLoadMoreButton() {
    if (elements.loadMoreBtn) {
      elements.loadMoreBtn.style.display = 'none';
    }
  }

  function showNotification(message, type = 'success') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification--${type}`;
    notification.textContent = message;
    notification.style.cssText = `
      position: fixed;
      top: 80px;
      right: 20px;
      padding: 1rem 1.5rem;
      background: ${type === 'success' ? '#10b981' : type === 'error' ? '#ef4444' : '#3b82f6'};
      color: white;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
      z-index: 1000;
      animation: slideIn 0.3s ease-out;
      font-weight: 600;
    `;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
      notification.style.animation = 'slideOut 0.3s ease-out';
      setTimeout(() => notification.remove(), 300);
    }, 3000);
  }

  function showError(message) {
    showNotification(message, 'error');
  }

  // ============================================
  // SOCIAL FEATURES
  // ============================================
  
  function shareRank(e) {
    e.preventDefault();
    
    const rank = state.userRank?.rank || '???';
    const score = state.userRank?.score || 0;
    
    const text = `I'm ranked #${rank} on the Meme Explorer leaderboard with ${score} points! Can you beat me? 🏆`;
    const url = window.location.href;
    
    if (navigator.share) {
      navigator.share({
        title: 'My Meme Explorer Rank',
        text: text,
        url: url
      }).catch(err => console.log('Share cancelled'));
    } else {
      // Fallback: copy to clipboard
      navigator.clipboard.writeText(`${text}\n${url}`).then(() => {
        showNotification('Rank copied to clipboard!', 'success');
      });
    }
  }

  // ============================================
  // AUTO-REFRESH
  // ============================================
  
  function startAutoRefresh() {
    // Refresh every 2 minutes
    setInterval(() => {
      if (!document.hidden && !state.loading) {
        console.log('🔄 Auto-refreshing leaderboard...');
        refreshLeaderboard();
      }
    }, 120000); // 2 minutes
  }

  // ============================================
  // UTILITIES
  // ============================================
  
  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // ============================================
  // START
  // ============================================
  
  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
