var h=(E,x,y)=>new Promise((k,S)=>{var M=m=>{try{b(y.next(m))}catch(g){S(g)}},L=m=>{try{b(y.throw(m))}catch(g){S(g)}},b=m=>m.done?k(m.value):Promise.resolve(m.value).then(M,L);b((y=y.apply(E,x)).next())});(function(){"use strict";window.handleMediaError=function(n){if(!n.dataset.errorHandled){n.dataset.errorHandled="true";const e=n.dataset.fallback;if(e&&n.src!==e){n.src=e;return}n.src="/images/meme-placeholder.svg",n.alt="Image failed to load",console.warn("Image failed to load:",n.dataset.originalSrc||n.src)}};class E{constructor(){this.currentIndex=0,this.images=[],this.init()}init(){console.log("[MemeDisplay] Initializing..."),this.bindCarouselControls(),this.setupImageErrorHandling()}bindCarouselControls(){const e=document.getElementById("carousel-prev"),t=document.getElementById("carousel-next");e&&e.addEventListener("click",()=>this.showPrevious()),t&&t.addEventListener("click",()=>this.showNext())}setupImageErrorHandling(){const e=document.getElementById("meme-image");e&&e.addEventListener("error",()=>this.handleImageError())}showPrevious(){this.currentIndex>0&&(this.currentIndex--,this.updateDisplay())}showNext(){this.currentIndex<this.images.length-1&&(this.currentIndex++,this.updateDisplay())}updateDisplay(){document.querySelectorAll(".gallery-slide").forEach((t,o)=>{t.classList.toggle("active",o===this.currentIndex)}),document.querySelectorAll(".gallery-dot").forEach((t,o)=>{t.classList.toggle("active",o===this.currentIndex)});const e=document.getElementById("carousel-counter")||document.querySelector(".gallery-counter");e&&this.images.length>1&&(e.textContent=`${this.currentIndex+1} / ${this.images.length}`,e.style.display="block"),console.log(`[MemeDisplay] Showing image ${this.currentIndex+1}/${this.images.length}`)}handleImageError(){console.warn("[MemeDisplay] Image failed to load"),typeof window.showPlaceholder=="function"&&window.showPlaceholder()}}class x{constructor(){this.loading=!1,this.prefetchedMeme=null,this.transitionDuration=140,this.init()}init(){console.log("[MemeNavigation] Initializing AJAX navigation..."),this.bindKeyboardShortcuts(),this.bindNavigationButtons(),this.setupPopStateHandler(),this.prefetchNext()}bindKeyboardShortcuts(){document.addEventListener("keydown",e=>this.handleKeyPress(e))}bindNavigationButtons(){document.querySelectorAll('[data-action="next-meme"], .next-button, #next-btn').forEach(o=>{o.addEventListener("click",s=>{s.preventDefault(),this.loadNextMeme()})}),document.querySelectorAll('[data-action="similar-meme"]').forEach(o=>{o.addEventListener("click",s=>{s.preventDefault();const i=o.dataset.subreddit;i&&this.loadSimilarMeme(i)})})}setupPopStateHandler(){window.addEventListener("popstate",e=>{e.state&&e.state.meme?this.renderMeme(e.state.meme,!1):window.location.reload()})}handleKeyPress(e){if(!this.isInputFocused()&&!e.repeat)switch(e.code){case"Space":case"ArrowRight":e.preventDefault(),this.loadNextMeme();break;case"ArrowLeft":e.preventDefault(),window.history.back();break;case"KeyL":e.preventDefault(),this.triggerLike();break;case"KeyS":e.preventDefault(),this.triggerSave();break;case"KeyT":e.preventDefault(),this.toggleTitle();break}}isInputFocused(){const e=document.activeElement;return e&&(e.tagName==="INPUT"||e.tagName==="TEXTAREA"||e.isContentEditable)}loadNextMeme(){return h(this,null,function*(){if(this.loading){console.log("[MemeNavigation] Already loading, please wait...");return}console.log("[MemeNavigation] Loading next meme via AJAX..."),this.loading=!0;try{this.showLoadingState();let e;if(this.prefetchedMeme)console.log("[MemeNavigation] Using prefetched meme"),e=this.prefetchedMeme,this.prefetchedMeme=null;else{const t=yield fetch("/random.json");if(!t.ok)throw new Error(`HTTP ${t.status}: ${t.statusText}`);e=yield t.json()}yield this.renderMeme(e),this.updateURL(e),this.prefetchNext(),this.trackView(e),console.log("[MemeNavigation] ✅ Meme loaded successfully")}catch(e){console.error("[MemeNavigation] Failed to load meme:",e),this.showError("Failed to load meme. Please try again."),setTimeout(()=>{window.location.href="/random"},2e3)}finally{this.loading=!1,this.hideLoadingState()}})}loadSimilarMeme(e){return h(this,null,function*(){if(!this.loading){console.log(`[MemeNavigation] Loading similar meme from r/${e}...`),this.loading=!0;try{this.showLoadingState();const t=yield fetch(`/similar.json?subreddit=${encodeURIComponent(e)}`);if(!t.ok)throw new Error(`HTTP ${t.status}`);const o=yield t.json();yield this.renderMeme(o),this.updateURL(o),this.prefetchNext(),this.trackView(o)}catch(t){console.error("[MemeNavigation] Failed to load similar meme:",t),this.showError("No similar memes found. Showing random instead."),setTimeout(()=>this.loadNextMeme(),1e3)}finally{this.loading=!1,this.hideLoadingState()}}})}renderMeme(e,t=!0){return h(this,null,function*(){const o=document.querySelector("#meme-display"),s=document.querySelector("#meme-info");if(!o){console.error("[MemeNavigation] #meme-display not found");return}o.classList.remove("meme-transition-in"),o.offsetWidth,o.classList.add("meme-transition-out"),yield this.wait(this.transitionDuration),o.innerHTML=this.renderMemeHTML(e),s&&(s.innerHTML=this.renderInfoHTML(e)),this.updateControlsState(e),o.classList.remove("meme-transition-out"),o.offsetWidth,o.classList.add("meme-transition-in"),this.flashPulse(),t&&this.updateURL(e),window.scrollTo({top:0,behavior:"smooth"})})}renderMemeHTML(e){var t,o;return e.media_type==="video"||(t=e.url)!=null&&t.includes("v.redd.it")?`
        <div class="meme-video-container">
          <video 
            src="${this.escapeHtml(e.url)}" 
            controls 
            autoplay 
            loop 
            playsinline
            class="meme-video"
          >
            Your browser doesn't support video playback.
          </video>
        </div>
      `:e.is_gallery&&((o=e.gallery_images)==null?void 0:o.length)>0?this.renderGalleryHTML(e.gallery_images,e.title):`
      <div class="meme-image-container">
        <img 
          src="${this.escapeHtml(e.url)}" 
          alt="${this.escapeHtml(e.title||"Meme")}"
          class="meme-image"
          loading="eager"
          onerror="this.src='/images/meme-placeholder.svg'"
        />
      </div>
    `}renderGalleryHTML(e,t){return`
      <div class="meme-gallery">
        <div class="gallery-container">
          ${e.map((s,i)=>`
      <div class="gallery-slide" data-index="${i}">
        <img 
          src="${this.escapeHtml(s.url||s)}" 
          alt="${this.escapeHtml(t)} - Image ${i+1}"
          class="gallery-image"
          loading="${i===0?"eager":"lazy"}"
        />
      </div>
    `).join("")}
        </div>
        <div class="gallery-controls">
          <button class="gallery-prev" onclick="window.memeApp?.navigation?.prevGalleryImage()">‹</button>
          <span class="gallery-counter">1 / ${e.length}</span>
          <button class="gallery-next" onclick="window.memeApp?.navigation?.nextGalleryImage()">›</button>
        </div>
      </div>
    `}renderInfoHTML(e){const t=this.escapeHtml(e.subreddit||"unknown"),o=this.escapeHtml(e.title||"Untitled Meme"),s=parseInt(e.likes)||0,i=e.diversity_pool||e.selection_method||"random";return`
      <h2 class="meme-title">${o}</h2>
      <div class="meme-meta">
        <span class="meme-subreddit">
          <a href="/category/${t}" title="View more from r/${t}">
            r/${t}
          </a>
        </span>
        <span class="meme-divider">•</span>
        <span class="meme-likes">${s} likes</span>
        ${i!=="random"?`
          <span class="meme-divider">•</span>
          <span class="meme-pool-type badge">${i}</span>
        `:""}
      </div>
      ${e.total_unseen?`
        <div class="memes-remaining">
          <small>${e.total_unseen} fresh memes remaining</small>
        </div>
      `:""}
    `}updateControlsState(e){const t=document.querySelector(".like-button");t&&(t.classList.remove("liked"),t.dataset.memeUrl=e.url);const o=document.querySelector(".like-count");o&&(o.textContent=e.likes||0);const s=document.querySelector(".save-button");s&&(s.classList.remove("saved"),s.dataset.memeUrl=e.url)}showLoadingState(){const e=document.querySelector("#meme-display");e&&e.classList.add("loading"),document.querySelectorAll(".meme-controls button").forEach(o=>o.disabled=!0)}hideLoadingState(){const e=document.querySelector("#meme-display");e&&e.classList.remove("loading"),document.querySelectorAll(".meme-controls button").forEach(o=>o.disabled=!1)}showError(e){const t=document.querySelector("#meme-display");t&&(t.innerHTML=`
        <div class="error-message">
          <p>⚠️ ${this.escapeHtml(e)}</p>
          <button onclick="location.reload()">Reload Page</button>
        </div>
      `)}updateURL(e){const t={meme:e},o=e.title||"Random Meme",s="/random";try{history.pushState(t,o,s),document.title=`${o} - Meme Explorer`}catch(i){console.warn("[MemeNavigation] Failed to update history:",i)}}prefetchNext(){this.loading||this.prefetchedMeme||(console.log("[MemeNavigation] Prefetching next meme..."),fetch("/random.json").then(e=>e.json()).then(e=>{if(this.prefetchedMeme=e,console.log("[MemeNavigation] ✅ Next meme prefetched"),e.url&&!e.url.includes("v.redd.it")){const t=new Image;t.src=e.url}}).catch(e=>{console.warn("[MemeNavigation] Prefetch failed:",e)}))}trackView(e){typeof gtag!="undefined"&&gtag("event","meme_view",{meme_url:e.url,subreddit:e.subreddit,pool_type:e.diversity_pool||"random"}),typeof window.trackMemeView=="function"&&window.trackMemeView(e)}toggleTitle(){const e=document.querySelector(".meme-title");e&&(e.style.display=e.style.display==="none"?"block":"none")}triggerLike(){const e=document.querySelector(".like-button");e&&e.click()}triggerSave(){const e=document.querySelector(".save-button");e&&e.click()}wait(e){return new Promise(t=>setTimeout(t,e))}flashPulse(){let e=document.querySelector(".meme-flash-pulse");e?(e.style.animation="none",e.offsetWidth,e.style.animation=""):(e=document.createElement("div"),e.className="meme-flash-pulse",document.body.appendChild(e))}escapeHtml(e){const t=document.createElement("div");return t.textContent=e,t.innerHTML}nextGalleryImage(){const e=document.querySelector(".gallery-container");if(!e)return;const t=e.querySelectorAll(".gallery-slide"),o=e.querySelector(".gallery-slide.active")||t[0],i=(parseInt(o.dataset.index)+1)%t.length;this.showGallerySlide(i)}prevGalleryImage(){const e=document.querySelector(".gallery-container");if(!e)return;const t=e.querySelectorAll(".gallery-slide"),o=e.querySelector(".gallery-slide.active")||t[0],s=parseInt(o.dataset.index),i=s===0?t.length-1:s-1;this.showGallerySlide(i)}showGallerySlide(e){const t=document.querySelectorAll(".gallery-slide"),o=document.querySelector(".gallery-counter");t.forEach((s,i)=>{s.classList.toggle("active",i===e)}),o&&(o.textContent=`${e+1} / ${t.length}`)}}class y{constructor(){this.isProcessing=!1,this.init()}init(){console.log("[MemeInteractions] Initializing Production Grade Edition..."),this.bindLikeButton(),this.bindSaveButton(),this.bindShareButton(),this.checkInitialStates(),this.addAnimationStyles()}addAnimationStyles(){if(document.getElementById("meme-interactions-styles"))return;const e=document.createElement("style");e.id="meme-interactions-styles",e.textContent=`
      @keyframes heartBeat {
        0%, 100% { transform: scale(1); }
        25% { transform: scale(1.3); }
        50% { transform: scale(1.1); }
        75% { transform: scale(1.2); }
      }
      
      @keyframes bookmarkSlide {
        0% { transform: translateY(0) scale(1); }
        50% { transform: translateY(-8px) scale(1.2); }
        100% { transform: translateY(0) scale(1); }
      }
      
      @keyframes ripple {
        0% { transform: scale(0); opacity: 1; }
        100% { transform: scale(4); opacity: 0; }
      }
      
      .btn-processing { opacity: 0.6; pointer-events: none; }
      .btn-liked { animation: heartBeat 0.6s ease; }
      .btn-saved { animation: bookmarkSlide 0.5s ease; }
      
      .ripple-effect {
        position: absolute;
        border-radius: 50%;
        background: rgba(255, 255, 255, 0.6);
        animation: ripple 0.6s ease-out;
        pointer-events: none;
      }
    `,document.head.appendChild(e)}bindLikeButton(){const e=document.getElementById("like-btn");e&&e.addEventListener("click",t=>this.handleLike(t))}bindSaveButton(){const e=document.getElementById("save-btn");e&&e.addEventListener("click",t=>this.handleSave(t))}bindShareButton(){const e=document.getElementById("share-btn");e&&e.addEventListener("click",()=>this.handleShare())}createRipple(e){const t=e.currentTarget,o=document.createElement("span");o.className="ripple-effect";const s=t.getBoundingClientRect(),i=Math.max(s.width,s.height),r=e.clientX-s.left-i/2,a=e.clientY-s.top-i/2;o.style.width=o.style.height=`${i}px`,o.style.left=`${r}px`,o.style.top=`${a}px`,t.style.position="relative",t.style.overflow="hidden",t.appendChild(o),setTimeout(()=>o.remove(),600)}triggerHaptic(e="medium"){if("vibrate"in navigator){const t={light:[10],medium:[20],heavy:[30],success:[10,50,10]};navigator.vibrate(t[e]||t.medium)}}handleLike(e){return h(this,null,function*(){if(this.isProcessing)return;console.log("[MemeInteractions] Like clicked"),this.createRipple(e);const t=this.getCurrentMemeUrl();if(!t){console.error("[MemeInteractions] No meme URL found");return}const o=document.getElementById("like-btn"),s=o==null?void 0:o.classList.contains("liked");this.isProcessing=!0,o==null||o.classList.add("btn-processing"),this.updateLikeButton(!s,!0),this.triggerHaptic(s?"light":"success");try{const i=yield fetch("/like",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({url:t})});if(i.ok){const r=yield i.json();console.log("[MemeInteractions] Like success:",r),this.updateLikeButton(r.liked,!1),this.showToast(r.liked?"❤️ Liked!":"Unliked","success"),r.likes!==void 0&&this.updateLikeCount(r.likes)}else{this.updateLikeButton(s,!1);const r=yield i.json();console.error("[MemeInteractions] Like failed:",r),this.showToast(r.error||"Error liking meme","error"),this.triggerHaptic("heavy")}}catch(i){this.updateLikeButton(s,!1),console.error("[MemeInteractions] Like request failed:",i),this.showToast("Network error","error"),this.triggerHaptic("heavy")}finally{this.isProcessing=!1,o==null||o.classList.remove("btn-processing")}})}handleSave(e){return h(this,null,function*(){var a,c;if(this.isProcessing)return;console.log("[MemeInteractions] Save clicked"),this.createRipple(e);const t=this.getCurrentMemeUrl();if(!t){console.error("[MemeInteractions] No meme URL found");return}const o=document.getElementById("save-btn"),s=o==null?void 0:o.classList.contains("saved"),i=((a=document.querySelector(".meme-title"))==null?void 0:a.textContent)||"Untitled Meme",r=((c=document.querySelector(".meme-subreddit"))==null?void 0:c.textContent)||"unknown";this.isProcessing=!0,o==null||o.classList.add("btn-processing"),this.updateSaveButton(!s,!0),this.triggerHaptic(s?"light":"success");try{const w=yield fetch(s?"/api/unsave-meme":"/api/save-meme",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(s?{url:t}:{url:t,title:i,subreddit:r})});if(w.ok){const v=yield w.json();console.log("[MemeInteractions] Save success:",v),this.updateSaveButton(!s,!1),this.showToast(s?"Removed from saved":"🔖 Saved to profile!","success")}else{this.updateSaveButton(s,!1);const v=yield w.json();console.error("[MemeInteractions] Save failed:",v),this.showToast(v.error||"Error saving meme","error"),this.triggerHaptic("heavy")}}catch(l){this.updateSaveButton(s,!1),console.error("[MemeInteractions] Save request failed:",l),this.showToast("Network error","error"),this.triggerHaptic("heavy")}finally{this.isProcessing=!1,o==null||o.classList.remove("btn-processing")}})}handleShare(){console.log("[MemeInteractions] Share clicked"),this.triggerHaptic("medium"),navigator.share?navigator.share({title:document.title,url:window.location.href}).then(()=>{this.showToast("Shared!","success")}).catch(e=>{e.name!=="AbortError"&&console.log("Share cancelled",e)}):navigator.clipboard.writeText(window.location.href).then(()=>{this.showToast("📤 Link copied!","success"),this.triggerHaptic("success")})}getCurrentMemeUrl(){const e=document.getElementById("meme-image");return e?e.src:null}updateLikeButton(e,t=!0){const o=document.getElementById("like-btn");if(o){t&&e&&(o.classList.add("btn-liked"),setTimeout(()=>o.classList.remove("btn-liked"),600)),o.classList.toggle("liked",e),o.setAttribute("aria-pressed",e);const s=o.querySelector("i, svg");s&&(s.style.color=e?"#e74c3c":"")}}updateSaveButton(e,t=!0){const o=document.getElementById("save-btn");if(o){t&&e&&(o.classList.add("btn-saved"),setTimeout(()=>o.classList.remove("btn-saved"),500)),o.classList.toggle("saved",e),o.setAttribute("aria-pressed",e);const s=o.querySelector("i, svg");s&&(s.style.color=e?"#f39c12":"")}}updateLikeCount(e){const t=document.getElementById("like-count");t&&(t.textContent=e,t.style.transform="scale(1.2)",setTimeout(()=>{t.style.transform="scale(1)"},200))}checkInitialStates(){const e=document.getElementById("like-btn"),t=document.getElementById("save-btn");e&&e.dataset.liked==="true"&&this.updateLikeButton(!0),t&&t.dataset.saved==="true"&&this.updateSaveButton(!0)}showToast(e,t="info"){document.querySelectorAll(".toast-notification").forEach(i=>i.remove());const o=document.createElement("div");o.className="toast-notification",o.textContent=e,o.setAttribute("role","status"),o.setAttribute("aria-live","polite");const s={success:"rgba(39, 174, 96, 0.95)",error:"rgba(231, 76, 60, 0.95)",info:"rgba(52, 73, 94, 0.95)"};o.style.cssText=`
      position: fixed;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: ${s[t]||s.info};
      color: white;
      padding: 12px 24px;
      border-radius: 8px;
      z-index: 10000;
      font-size: 14px;
      font-weight: 500;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      transition: transform 0.2s ease;
      animation: fadeIn 0.3s, fadeOut 0.3s 2.7s;
    `,document.body.appendChild(o),o.addEventListener("mouseenter",()=>{o.style.transform="translateX(-50%) translateY(-4px)"}),o.addEventListener("mouseleave",()=>{o.style.transform="translateX(-50%) translateY(0)"}),setTimeout(()=>{o.style.opacity="0",setTimeout(()=>o.remove(),300)},3e3)}}class k{constructor(){this.display=null,this.navigation=null,this.interactions=null,this.tracking=null,this.prefetch=null,this.init()}init(){return h(this,null,function*(){console.log("[MemeApp] Initializing..."),this.display=new E,this.navigation=new x,this.interactions=new y,console.log("[MemeApp] Initialized successfully"),window.location.hostname==="localhost"&&(window.memeApp=this)})}}document.readyState==="loading"?document.addEventListener("DOMContentLoaded",()=>new k):new k,function(){const n={config:{enabled:!0,shortcuts:{j:"nextMeme",k:"previousMeme",l:"likeMeme",s:"saveMeme",S:"shareMeme","?":"showHelp",Escape:"closeModals"}},state:{helpModalVisible:!1,inputFocused:!1},init(){console.log("🎹 Initializing keyboard navigation..."),this.setupEventListeners(),this.createHelpModal(),this.detectInputFocus(),console.log("✅ Keyboard navigation ready")},setupEventListeners(){document.addEventListener("keydown",e=>{if(this.state.inputFocused||document.body.classList.contains("modal-open")&&e.key!=="Escape")return;const t=this.getHandlerForKey(e);t&&(e.preventDefault(),this[t]())})},getHandlerForKey(e){const t=e.shiftKey&&e.key.toLowerCase()!==e.key?e.key:e.key.toLowerCase();return this.config.shortcuts[t]||this.config.shortcuts[e.key]},detectInputFocus(){document.addEventListener("focusin",e=>{e.target.matches('input, textarea, select, [contenteditable="true"]')&&(this.state.inputFocused=!0)}),document.addEventListener("focusout",e=>{e.target.matches('input, textarea, select, [contenteditable="true"]')&&(this.state.inputFocused=!1)})},nextMeme(){console.log("⏭️ Next meme (j)");const e=document.querySelector('[data-action="next-meme"], .next-button, button[onclick*="next"]');e?(e.click(),this.showFeedback("Next meme")):typeof window.nextMeme=="function"?window.nextMeme():typeof window.loadNextMeme=="function"&&window.loadNextMeme()},previousMeme(){console.log("⏮️ Previous meme (k)");const e=document.querySelector('[data-action="prev-meme"], .prev-button, button[onclick*="prev"]');e?(e.click(),this.showFeedback("Previous meme")):typeof window.previousMeme=="function"?window.previousMeme():typeof window.loadPreviousMeme=="function"&&window.loadPreviousMeme()},likeMeme(){console.log("❤️ Like meme (l)");const e=document.querySelector('[data-action="like"], .like-button, button[onclick*="like"]');e?(e.click(),this.showFeedback("Liked!")):typeof window.likeMeme=="function"&&window.likeMeme()},saveMeme(){console.log("💾 Save meme (s)");const e=document.querySelector('[data-action="save"], .save-button, button[onclick*="save"]');e?(e.click(),this.showFeedback("Saved!")):typeof window.saveMeme=="function"&&window.saveMeme()},shareMeme(){console.log("📤 Share meme (Shift+S)");const e=document.querySelector('[data-action="share"], .share-button, button[onclick*="share"]');e?(e.click(),this.showFeedback("Share opened")):typeof window.shareMeme=="function"&&window.shareMeme()},showHelp(){console.log("❓ Show help (?)"),this.state.helpModalVisible=!0;const e=document.getElementById("keyboard-shortcuts-modal");e&&(e.style.display="flex",e.setAttribute("aria-hidden","false"),document.body.classList.add("modal-open"))},closeModals(){console.log("❌ Close modals (Esc)");const e=document.getElementById("keyboard-shortcuts-modal");e&&(e.style.display="none",e.setAttribute("aria-hidden","true"),document.body.classList.remove("modal-open"),this.state.helpModalVisible=!1),document.querySelectorAll('.modal:not([aria-hidden="true"])').forEach(o=>{o.style.display="none",o.setAttribute("aria-hidden","true")})},showFeedback(e){const t=document.querySelector(".keyboard-feedback");t&&t.remove();const o=document.createElement("div");o.className="keyboard-feedback",o.textContent=e,o.style.cssText=`
        position: fixed;
        bottom: 20px;
        right: 20px;
        background: rgba(0, 0, 0, 0.8);
        color: white;
        padding: 12px 20px;
        border-radius: 8px;
        font-size: 14px;
        font-weight: 500;
        z-index: 10000;
        animation: feedbackSlide 0.3s ease-out;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
      `,document.body.appendChild(o),setTimeout(()=>{o.style.animation="feedbackSlideOut 0.3s ease-out",setTimeout(()=>o.remove(),300)},1500)},createHelpModal(){if(document.getElementById("keyboard-shortcuts-modal"))return;const e=document.createElement("div");e.id="keyboard-shortcuts-modal",e.className="modal",e.setAttribute("role","dialog"),e.setAttribute("aria-labelledby","shortcuts-title"),e.setAttribute("aria-hidden","true"),e.style.display="none",e.innerHTML=`
        <div class="modal-overlay" onclick="document.getElementById('keyboard-shortcuts-modal').style.display='none'"></div>
        <div class="modal-content" style="max-width: 500px;">
          <div class="modal-header">
            <h2 id="shortcuts-title">⌨️ Keyboard Shortcuts</h2>
            <button class="modal-close" onclick="document.getElementById('keyboard-shortcuts-modal').style.display='none'" aria-label="Close">×</button>
          </div>
          <div class="modal-body">
            <div class="shortcuts-grid">
              <div class="shortcut-item">
                <kbd>j</kbd>
                <span>Next meme</span>
              </div>
              <div class="shortcut-item">
                <kbd>k</kbd>
                <span>Previous meme</span>
              </div>
              <div class="shortcut-item">
                <kbd>l</kbd>
                <span>Like current meme</span>
              </div>
              <div class="shortcut-item">
                <kbd>s</kbd>
                <span>Save/bookmark</span>
              </div>
              <div class="shortcut-item">
                <kbd>Shift</kbd> + <kbd>S</kbd>
                <span>Share meme</span>
              </div>
              <div class="shortcut-item">
                <kbd>?</kbd>
                <span>Show this help</span>
              </div>
              <div class="shortcut-item">
                <kbd>Esc</kbd>
                <span>Close modals</span>
              </div>
            </div>
            <div class="shortcuts-tip">
              💡 <strong>Pro tip:</strong> Keyboard shortcuts won't work while typing in text fields.
            </div>
          </div>
        </div>
      `;const t=document.createElement("style");t.textContent=`
        .keyboard-shortcuts-modal .modal-overlay {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background: rgba(0, 0, 0, 0.5);
          z-index: 9998;
        }

        .keyboard-shortcuts-modal .modal-content {
          position: fixed;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          background: white;
          border-radius: 12px;
          padding: 0;
          z-index: 9999;
          max-height: 90vh;
          overflow-y: auto;
          box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        }

        .keyboard-shortcuts-modal .modal-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 20px 24px;
          border-bottom: 1px solid #e5e7eb;
        }

        .keyboard-shortcuts-modal .modal-header h2 {
          margin: 0;
          font-size: 20px;
          font-weight: 600;
        }

        .keyboard-shortcuts-modal .modal-close {
          background: none;
          border: none;
          font-size: 28px;
          cursor: pointer;
          color: #6b7280;
          line-height: 1;
          padding: 0;
          width: 32px;
          height: 32px;
          display: flex;
          align-items: center;
          justify-content: center;
          border-radius: 6px;
          transition: all 0.2s;
        }

        .keyboard-shortcuts-modal .modal-close:hover {
          background: #f3f4f6;
          color: #111827;
        }

        .keyboard-shortcuts-modal .modal-body {
          padding: 24px;
        }

        .keyboard-shortcuts-modal .shortcuts-grid {
          display: grid;
          gap: 16px;
        }

        .keyboard-shortcuts-modal .shortcut-item {
          display: flex;
          align-items: center;
          gap: 16px;
        }

        .keyboard-shortcuts-modal .shortcut-item kbd {
          background: #f3f4f6;
          border: 1px solid #d1d5db;
          border-radius: 6px;
          padding: 6px 12px;
          font-family: 'SF Mono', 'Monaco', 'Inconsolata', 'Roboto Mono', monospace;
          font-size: 13px;
          font-weight: 600;
          color: #374151;
          box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
          min-width: 40px;
          text-align: center;
        }

        .keyboard-shortcuts-modal .shortcut-item span {
          flex: 1;
          color: #6b7280;
          font-size: 14px;
        }

        .keyboard-shortcuts-modal .shortcuts-tip {
          margin-top: 20px;
          padding: 12px 16px;
          background: #eff6ff;
          border-radius: 8px;
          font-size: 13px;
          color: #1e40af;
          border-left: 3px solid #3b82f6;
        }

        @keyframes feedbackSlide {
          from {
            transform: translateY(20px);
            opacity: 0;
          }
          to {
            transform: translateY(0);
            opacity: 1;
          }
        }

        @keyframes feedbackSlideOut {
          from {
            transform: translateY(0);
            opacity: 1;
          }
          to {
            transform: translateY(20px);
            opacity: 0;
          }
        }

        @media (max-width: 640px) {
          .keyboard-shortcuts-modal .modal-content {
            width: 90%;
            max-width: none;
          }

          .keyboard-shortcuts-modal .shortcut-item {
            gap: 12px;
          }

          .keyboard-shortcuts-modal .shortcut-item kbd {
            min-width: 36px;
            padding: 4px 8px;
            font-size: 12px;
          }
        }
      `,document.head.appendChild(t),document.body.appendChild(e),e.querySelector(".modal-overlay").addEventListener("click",()=>{this.closeModals()}),e.querySelectorAll(".modal-close").forEach(o=>{o.addEventListener("click",()=>{this.closeModals()})})}};document.readyState==="loading"?document.addEventListener("DOMContentLoaded",()=>n.init()):n.init(),window.KeyboardNavigation=n}(),function(){const n={swipeThreshold:50,velocityThreshold:.3,maxVerticalDrift:75,feedbackOpacity:.3};let e=0,t=0,o=0,s=!1,i=null;function r(){if(!("ontouchstart"in window)){console.log("📱 Swipe gestures: Not a touch device, skipping");return}console.log("📱 Swipe gestures: Initializing..."),a(),document.addEventListener("touchstart",c,{passive:!1}),document.addEventListener("touchmove",l,{passive:!1}),document.addEventListener("touchend",u,{passive:!1}),console.log("✅ Swipe gestures: Ready")}function a(){i=document.createElement("div"),i.id="swipe-overlay",i.style.cssText=`
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      z-index: 9999;
      display: none;
      background: linear-gradient(90deg, 
        transparent 0%, 
        rgba(103, 126, 234, ${n.feedbackOpacity}) 50%, 
        transparent 100%
      );
      transition: opacity 0.2s;
    `,document.body.appendChild(i)}function c(d){if(d.target.tagName==="INPUT"||d.target.tagName==="TEXTAREA"||d.target.closest("button, a"))return;const p=d.touches[0];e=p.clientX,t=p.clientY,o=Date.now(),s=!1}function l(d){if(!e)return;const p=d.touches[0],f=p.clientX-e,I=Math.abs(p.clientY-t);Math.abs(f)>10&&I<n.maxVerticalDrift&&(s=!0,i&&(i.style.display="block",i.style.opacity=Math.min(Math.abs(f)/n.swipeThreshold,1),f>0?i.style.background=`linear-gradient(90deg, 
            rgba(103, 126, 234, ${n.feedbackOpacity}) 0%, 
            transparent 50%
          )`:i.style.background=`linear-gradient(90deg, 
            transparent 50%, 
            rgba(103, 126, 234, ${n.feedbackOpacity}) 100%
          )`),Math.abs(f)>n.swipeThreshold/2&&d.preventDefault())}function u(d){if(!e||!s){e=0,t=0,w();return}const p=d.changedTouches[0],f=p.clientX-e,I=Math.abs(p.clientY-t),H=Date.now()-o,z=Math.abs(f)/H;Math.abs(f)>n.swipeThreshold&&I<n.maxVerticalDrift&&z>n.velocityThreshold&&(f>0?(console.log("📱 Swipe: Previous meme"),U()):(console.log("📱 Swipe: Next meme"),v()),window.hapticSystem&&window.hapticSystem.trigger("light"),window.soundSystem&&!window.soundSystem.isMuted()&&window.soundSystem.play("click")),e=0,t=0,s=!1,w()}function w(){i&&(i.style.opacity="0",setTimeout(()=>{i.style.display="none"},200))}function v(){if(window.memeNavigation&&window.memeNavigation.nextMeme){window.memeNavigation.nextMeme();return}const d=document.getElementById("next-btn")||document.querySelector('[data-action="next"]');if(d){d.click();return}window.location.href="/random"}function U(){if(window.memeNavigation&&window.memeNavigation.previousMeme){window.memeNavigation.previousMeme();return}const d=document.getElementById("prev-btn")||document.querySelector('[data-action="previous"]');if(d){d.click();return}window.location.href="/random"}function O(){document.removeEventListener("touchstart",c),document.removeEventListener("touchmove",l),document.removeEventListener("touchend",u),i&&i.parentNode&&i.parentNode.removeChild(i),console.log("📱 Swipe gestures: Destroyed")}document.readyState==="loading"?document.addEventListener("DOMContentLoaded",r):r(),window.mobileSwipe={init:r,destroy:O,config:n},console.log("📱 Mobile swipe module loaded")}(),function(){const n={init(){this.memeCount=parseInt(localStorage.getItem("memes-viewed")||"0"),this.checkMilestones(),this.trackMemeViews()},trackMemeViews(){const e=new MutationObserver(()=>{this.incrementMemeCount()}),t=document.querySelector(".meme-display, .meme-container, #meme-image");t&&e.observe(t,{attributes:!0,attributeFilter:["src","data-meme-id"]});let o=location.href;new MutationObserver(()=>{location.href!==o&&(o=location.href,this.incrementMemeCount())}).observe(document,{subtree:!0,childList:!0})},incrementMemeCount(){this.memeCount++,localStorage.setItem("memes-viewed",this.memeCount),this.checkMilestones()},checkMilestones(){this.memeCount===5&&!this.hasSeenMilestone("keyboard-shortcuts")&&this.showFeatureUnlock({title:"⌨️ Keyboard Shortcuts Unlocked!",description:"You've viewed 5 memes! Press Space for next, L to like, S to save.",cta:"Try it now",milestone:"keyboard-shortcuts"}),this.memeCount===10&&!this.hasSeenMilestone("gamification")&&this.showFeatureUnlock({title:"🎮 Stats Tracking Unlocked!",description:"Check your stats in the top-right corner. Build streaks, earn achievements!",cta:"View Stats",milestone:"gamification",callback:()=>this.openGamificationPanel()}),this.memeCount===25&&!this.hasSeenMilestone("collections")&&this.showFeatureUnlock({title:"⭐ Collections Available!",description:"Create custom meme collections. Save your favorites and share them!",cta:"Create Collection",milestone:"collections"})},hasSeenMilestone(e){return localStorage.getItem(`milestone-${e}`)==="1"},markMilestoneSeen(e){localStorage.setItem(`milestone-${e}`,"1")},showFeatureUnlock(e){const{title:t,description:o,cta:s,milestone:i,callback:r}=e,a=document.createElement("div");a.className="feature-unlock",a.innerHTML=`
        <div style="font-size: 48px; margin-bottom: 16px;">🎉</div>
        <h3>${t}</h3>
        <p>${o}</p>
        <button class="unlock-cta">${s}</button>
      `,document.body.appendChild(a),a.querySelector(".unlock-cta").addEventListener("click",()=>{this.markMilestoneSeen(i),a.remove(),r&&r()}),setTimeout(()=>{document.body.contains(a)&&(this.markMilestoneSeen(i),a.remove())},1e4)},openGamificationPanel(){const e=document.querySelector(".gamification-collapsed");e&&(e.classList.remove("gamification-collapsed"),e.classList.add("gamification-expanded"))}};document.readyState==="loading"?document.addEventListener("DOMContentLoaded",()=>n.init()):n.init()}(),function(){const n={rootMargin:"50px 0px",threshold:.01},e=new Set,t=new IntersectionObserver((a,c)=>{a.forEach(l=>{if(l.isIntersecting){const u=l.target;o(u),c.unobserve(u)}})},n);function o(a){const c=a.dataset.src||a.getAttribute("data-src");if(!c||e.has(c))return;const l=a.dataset.srcset||a.getAttribute("data-srcset"),u=new Image;u.onload=()=>{a.src=c,l&&(a.srcset=l),a.classList.add("loaded"),e.add(c),a.dispatchEvent(new CustomEvent("imageLoaded",{detail:{src:c,loadTime:performance.now()}}))},u.onerror=()=>{console.error("Failed to load image:",c),a.classList.add("error"),a.src="/images/meme-placeholder.svg"},u.src=c}function s(){const a=document.querySelectorAll('img[data-src], img[loading="lazy"]');let c=0;a.forEach(l=>{l.getAttribute("fetchpriority")==="high"||l.getAttribute("loading")==="eager"||(l.classList.add("lazy-loading"),t.observe(l),c++)}),c>0&&console.log(`✅ Enhanced lazy loading initialized for ${c} images`)}function i(a){if(!a||e.has(a))return;const c=document.createElement("link");c.rel="prefetch",c.as="image",c.href=a,document.head.appendChild(c),e.add(a)}document.readyState==="loading"?document.addEventListener("DOMContentLoaded",s):s(),new MutationObserver(a=>{let c=!1;a.forEach(l=>{l.addedNodes.forEach(u=>{u.nodeType===1&&(u.tagName==="IMG"||u.querySelector("img"))&&(c=!0)})}),c&&s()}).observe(document.body,{childList:!0,subtree:!0}),window.LazyLoad={init:s,prefetch:i,isLoaded:a=>e.has(a)}}(),function(){const n={lcp:null,fid:null,cls:null};if("PerformanceObserver"in window){try{new PerformanceObserver(t=>{const o=t.getEntries(),s=o[o.length-1];n.lcp=Math.round(s.renderTime||s.loadTime),n.lcp>2500&&console.warn(`⚠️ LCP: ${n.lcp}ms (needs improvement)`),e("lcp",n.lcp)}).observe({type:"largest-contentful-paint",buffered:!0})}catch(t){console.error("LCP tracking error:",t)}try{new PerformanceObserver(t=>{t.getEntries().forEach(o=>{n.fid=Math.round(o.processingStart-o.startTime),n.fid>100&&console.warn(`⚠️ FID: ${n.fid}ms (needs improvement)`),e("fid",n.fid)})}).observe({type:"first-input",buffered:!0})}catch(t){console.error("FID tracking error:",t)}try{let t=0;new PerformanceObserver(o=>{o.getEntries().forEach(s=>{s.hadRecentInput||(t+=s.value)}),n.cls=Math.round(t*1e3)/1e3,n.cls>.1&&console.warn(`⚠️ CLS: ${n.cls} (needs improvement)`)}).observe({type:"layout-shift",buffered:!0}),window.addEventListener("beforeunload",()=>{e("cls",n.cls)})}catch(t){console.error("CLS tracking error:",t)}console.log("✅ Core Web Vitals tracking initialized")}else console.warn("⚠️ PerformanceObserver not supported");function e(t,o){if(o)try{fetch("/api/vitals",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({metric:t,value:o,url:window.location.pathname,timestamp:Date.now()}),keepalive:!0}).catch(s=>console.error("Analytics error:",s))}catch(s){console.error("Failed to send vital:",s)}}window.getWebVitals=()=>n}();class S{constructor(e={}){this.frequency=e.frequency||parseInt(window.AD_FREQUENCY||"12",10),this.adSenseClient=e.adSenseClient||window.GOOGLE_ADSENSE_CLIENT||null,this.adSlots={square:e.squareSlot||window.GOOGLE_AD_SLOT_SQUARE||null,banner:e.bannerSlot||window.GOOGLE_AD_SLOT_BANNER||null,native:e.nativeSlot||window.GOOGLE_AD_SLOT_NATIVE||null},this.userIsPremium=e.isPremium||!1,this.adsDisabled=e.disabled||!1,this.adCount=0,this.impressions=[],this.minItemsForAds=6,console.log("📢 [AD MANAGER] Initialized:",{frequency:this.frequency,enabled:this.shouldShowAds(),client:this.adSenseClient?"✓":"✗",minItems:this.minItemsForAds})}shouldShowAds(){const e=window.location.pathname;return["/login","/signup","/auth/","/api/","/logout"].some(o=>e.includes(o))?(console.log("📢 [AD MANAGER] Ads disabled for this page:",e),!1):!this.userIsPremium&&!this.adsDisabled}shouldShowAdAtPosition(e){return e===0||!this.shouldShowAds()?!1:(e+1)%this.frequency===0}createAdElement(e,t="square"){const o=document.createElement("div");o.className="ad-container",o.setAttribute("data-ad-index",e),o.setAttribute("data-ad-format",t);const s=document.createElement("div");if(s.className="ad-label",s.textContent="Advertisement",o.appendChild(s),this.adSenseClient&&this.adSlots[t]){const i=this.createAdSenseUnit(t);o.appendChild(i),this.impressions.push({element:i,index:e,format:t,loaded:!1})}else{const i=this.createPlaceholder(t);o.appendChild(i)}return o}createAdSenseUnit(e){const t=document.createElement("ins");t.className="adsbygoogle",t.setAttribute("data-ad-client",this.adSenseClient),t.setAttribute("data-ad-slot",this.adSlots[e]);const o=this.getAdDimensions(e);return t.style.display="inline-block",t.style.width=o.width,t.style.height=o.height,e==="native"?(t.setAttribute("data-ad-format","auto"),t.setAttribute("data-full-width-responsive","true")):t.setAttribute("data-ad-format","rectangle"),t}getAdDimensions(e){switch(e){case"banner":return{width:"728px",height:"90px"};case"native":return{width:"100%",height:"auto"};default:return{width:"300px",height:"250px"}}}createPlaceholder(e){const t=this.getAdDimensions(e),o=document.createElement("div");return o.className="ad-demo-content ad-placeholder",o.style.width=t.width,o.style.height=t.height,o.innerHTML=`
      <div class="ad-demo-text">
        <strong>Ad Placeholder</strong><br>
        <small>Configure ads in .env</small><br>
        <span style="font-size: 11px; opacity: 0.7;">${t.width} × ${t.height}</span>
      </div>
    `,o}insertAdsIntoContainer(e,t){if(!this.shouldShowAds())return;const o=Array.from(e.querySelectorAll(t));if(o.length<this.minItemsForAds){console.log(`📢 [AD MANAGER] Insufficient content (${o.length} < ${this.minItemsForAds}), no ads inserted`);return}let s=0;o.forEach((i,r)=>{if(this.shouldShowAdAtPosition(r)){const a=this.createAdElement(this.adCount,"square");i.parentNode.insertBefore(a,i),s++,this.adCount++}}),console.log(`📢 [AD MANAGER] Inserted ${s} ads`),this.adSenseClient&&s>0&&this.loadAdSenseAds()}insertAdAtPosition(e,t,o="square"){if(!this.shouldShowAds())return null;const s=this.createAdElement(this.adCount,o);return e.insertBefore(s,t),this.adCount++,this.adSenseClient&&this.loadAdSenseAds(),s}loadAdSenseAds(){if(!window.adsbygoogle){console.warn("⚠️ [AD MANAGER] AdSense script not loaded");return}this.loadTimeout&&clearTimeout(this.loadTimeout),this.loadTimeout=setTimeout(()=>{const e=this.impressions.filter(t=>!t.loaded);e.length!==0&&(console.log(`📢 [AD MANAGER] Loading ${e.length} new ad(s)...`),e.forEach(t=>{try{if(!t.element.isConnected){console.warn(`⚠️ [AD MANAGER] Ad #${t.index} element removed from DOM, skipping`);return}(window.adsbygoogle=window.adsbygoogle||[]).push({}),t.loaded=!0,console.log(`✅ [AD MANAGER] Loaded ad #${t.index}`),this.trackAdImpression(t)}catch(o){console.error(`❌ [AD MANAGER] Error loading ad #${t.index}:`,o.message)}}))},100)}trackAdImpression(e){window.activityTracker&&window.activityTracker.track("ad_impression",{ad_index:e.index,ad_format:e.format,ad_frequency:this.frequency})}setupLazyLoading(){if(!("IntersectionObserver"in window))return;const e=new IntersectionObserver(t=>{t.forEach(o=>{if(o.isIntersecting){const s=o.target,i=parseInt(s.getAttribute("data-ad-index"),10);console.log(`👁️ [AD MANAGER] Ad #${i} in viewport`),window.activityTracker&&window.activityTracker.track("ad_viewable",{ad_index:i}),e.unobserve(s)}})},{threshold:.5,rootMargin:"50px"});document.querySelectorAll(".ad-container").forEach(t=>{e.observe(t)})}}window.AdManager=S,function(){if(!("IntersectionObserver"in window)){console.warn("[Ad Lazy Load] Intersection Observer not supported, loading ads immediately");return}const n={rootMargin:"50px 0px",threshold:.01},e=new IntersectionObserver(function(s){s.forEach(function(i){if(i.isIntersecting){const r=i.target;r.dataset.adUnit&&!r.classList.contains("ad-loaded")&&(o(r),e.unobserve(r))}})},n);function t(){const s=document.querySelectorAll('.ad-container[data-lazy="true"]');s.forEach(function(i){e.observe(i)}),console.log(`[Ad Lazy Load] Observing ${s.length} ad containers`)}function o(s){const i=s.dataset.adUnit;try{(adsbygoogle=window.adsbygoogle||[]).push({}),s.classList.add("ad-loaded"),console.log(`[Ad Lazy Load] Loaded ad: ${i}`)}catch(r){console.error("[Ad Lazy Load] Error loading ad:",r)}}document.readyState==="loading"?document.addEventListener("DOMContentLoaded",t):t()}(),document.addEventListener("DOMContentLoaded",function(){M(),$()});function M(){document.querySelectorAll(".meme-container, .meme-detail, .meme-card").forEach(e=>{e.querySelector(".share-bar")||L(e)})}function L(n){var s;const e=n.dataset.url||window.location.href,t=n.dataset.title||document.title;(s=n.querySelector("img"))!=null&&s.src;const o=document.createElement("div");o.className="share-bar",o.innerHTML=`
    <button class="share-btn whatsapp" onclick="shareToWhatsApp('${encodeURIComponent(t)}', '${encodeURIComponent(e)}')">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
        <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
      </svg>
      WhatsApp
    </button>
    
    <button class="share-btn twitter" onclick="shareToTwitter('${encodeURIComponent(t)}', '${encodeURIComponent(e)}')">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
        <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>
      </svg>
      Tweet
    </button>
    
    <button class="share-btn copy" onclick="copyLink('${e}')" title="Copy link">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
        <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
      </svg>
      Copy Link
    </button>
  `,n.appendChild(o)}function b(n,e){const t=`Check out this meme! ${n}`,o=`https://wa.me/?text=${encodeURIComponent(t+" "+e)}`;window.open(o,"_blank"),typeof trackEvent=="function"&&trackEvent("share","whatsapp",n)}function m(n,e){const t=`https://twitter.com/intent/tweet?text=${encodeURIComponent(n)}&url=${encodeURIComponent(e)}&hashtags=memes`;window.open(t,"_blank","width=550,height=420"),typeof trackEvent=="function"&&trackEvent("share","twitter",n)}function g(n){navigator.clipboard&&window.isSecureContext?navigator.clipboard.writeText(n).then(()=>{T()}).catch(e=>{C(n)}):C(n),typeof trackEvent=="function"&&trackEvent("share","copy_link",n)}function C(n){const e=document.createElement("textarea");e.value=n,e.style.position="fixed",e.style.left="-999999px",e.style.top="-999999px",document.body.appendChild(e),e.focus(),e.select();try{document.execCommand("copy"),T()}catch(t){console.error("Failed to copy:",t),alert("Failed to copy link. Please copy manually: "+n)}document.body.removeChild(e)}function T(){const n=document.createElement("div");n.className="copy-toast",n.textContent="✓ Link copied to clipboard!",document.body.appendChild(n),setTimeout(()=>n.classList.add("show"),10),setTimeout(()=>{n.classList.remove("show"),setTimeout(()=>document.body.removeChild(n),300)},3e3)}function $(){document.querySelectorAll(".meme-actions").forEach(n=>{if(!n.querySelector(".share-btn")){const e=document.createElement("button");e.className="btn share-btn-primary",e.innerHTML="🔗 Share This Meme",e.onclick=function(){g(window.location.href)},n.appendChild(e)}})}function P(n,e,t){navigator.share?navigator.share({title:n,text:t||n,url:e}).then(()=>{typeof trackEvent=="function"&&trackEvent("share","native",n)}).catch(o=>console.log("Error sharing:",o)):g(e)}window.shareToWhatsApp=b,window.shareToTwitter=m,window.copyLink=g,window.nativeShare=P,function(){const n="meme-explorer-theme";function e(){const r=localStorage.getItem(n);return r||(window.matchMedia("(prefers-color-scheme: dark)").matches?"dark":"light")}function t(r){document.documentElement.setAttribute("data-theme",r),o(r)}function o(r){const a=document.getElementById("theme-toggle");a&&(a.textContent=r==="dark"?"☀️":"🌙",a.setAttribute("aria-label",`Switch to ${r==="dark"?"light":"dark"} mode`))}function s(){const a=(document.documentElement.getAttribute("data-theme")||e())==="dark"?"light":"dark";localStorage.setItem(n,a),t(a),typeof gtag!="undefined"&&gtag("event","theme_change",{theme:a})}function i(){const r=e();t(r),window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change",a=>{localStorage.getItem(n)||t(a.matches?"dark":"light")})}document.readyState==="loading"?document.addEventListener("DOMContentLoaded",i):i(),window.toggleTheme=s}();class N{constructor(e){this.moduleName=e,this.errors=[]}wrap(e){return(...t)=>{try{return e(...t)}catch(o){return this.handleError(o),null}}}wrapAsync(e){return h(this,null,function*(){return(...t)=>h(this,null,function*(){try{return yield e(...t)}catch(o){return this.handleError(o),null}})})}handleError(e){console.error(`[${this.moduleName}] Error:`,e),window.AppLogger&&window.AppLogger.error({module:this.moduleName,error:e.message,stack:e.stack}),this.errors.push({timestamp:new Date,error:e.message,stack:e.stack}),this.showUserMessage()}showUserMessage(){if(sessionStorage.getItem(`error_shown_${this.moduleName}`))return;const e=`We encountered an issue with ${this.moduleName}. Please refresh the page.`;window.showToast?window.showToast(e,"error"):console.warn(e),sessionStorage.setItem(`error_shown_${this.moduleName}`,"true")}getErrors(){return this.errors}}typeof module!="undefined"&&module.exports?module.exports=N:window.ErrorBoundary=N,function(){const n=typeof Sentry!="undefined";window.addEventListener("error",function(e){return console.error("[Global Error]",{message:e.message,filename:e.filename,lineno:e.lineno,colno:e.colno,error:e.error}),n&&Sentry.captureException(e.error||new Error(e.message)),!1}),window.addEventListener("unhandledrejection",function(e){console.error("[Unhandled Promise Rejection]",e.reason),n&&Sentry.captureException(e.reason)}),console.log("[Error Handler] Global error handler initialized")}(),"serviceWorker"in navigator&&!sessionStorage.getItem("sw-refresh-done")&&navigator.serviceWorker.getRegistrations().then(function(n){if(n.length===0){sessionStorage.setItem("sw-refresh-done","1");return}Promise.all(n.map(function(e){return e.unregister().then(function(t){console.log("[SW] Unregistered old service worker:",t)})})).then(function(){sessionStorage.setItem("sw-refresh-done","1"),console.log("[SW] Reloading once to register fresh service worker..."),window.location.reload()})});function D(){const n=document.querySelector(".mobile-nav");n&&n.classList.toggle("open")}function B(n){document.documentElement.setAttribute("data-theme",n),localStorage.setItem("theme",n)}function A(){const n=localStorage.getItem("theme")||"light";B(n)}document.readyState==="loading"?document.addEventListener("DOMContentLoaded",A):A(),typeof module!="undefined"&&module.exports&&(module.exports={toggleMobileNav:D,setTheme:B,initTheme:A});class q{constructor(){this.consentKey="meme_explorer_cookie_consent",this.consentValue=localStorage.getItem(this.consentKey),this.isEU=this.detectEUUser(),this.isEU&&!this.consentValue?(this.showBanner(),this.blockMonetag()):(this.consentValue==="accepted"||!this.isEU)&&this.loadMonetag()}detectEUUser(){const e=["Europe/London","Europe/Paris","Europe/Berlin","Europe/Rome","Europe/Madrid","Europe/Amsterdam","Europe/Brussels","Europe/Vienna","Europe/Stockholm","Europe/Warsaw","Europe/Prague","Europe/Budapest","Europe/Athens","Europe/Lisbon","Europe/Dublin","Europe/Helsinki","Europe/Copenhagen","Europe/Bucharest","Europe/Sofia","Europe/Zagreb","Europe/Vilnius","Europe/Riga","Europe/Tallinn","Europe/Ljubljana","Europe/Bratislava","Europe/Luxembourg","Europe/Valletta","Europe/Nicosia"];try{const t=Intl.DateTimeFormat().resolvedOptions().timeZone;return e.includes(t)}catch(t){return console.warn("Cookie Consent: Could not detect timezone, assuming non-EU"),!1}}showBanner(){const e=document.createElement("div");e.id="cookie-consent-banner",e.innerHTML=`
      <div class="cookie-consent-content">
        <p><strong>🍪 This Site Uses Cookies</strong></p>
        <p>We and our advertising partners (Monetag/PropellerAds, Google AdSense) use cookies and similar technologies to personalize content and ads, provide social media features, and analyze our traffic. By clicking "Accept", you consent to our use of cookies.</p>
        <div class="cookie-consent-buttons">
          <button id="cookie-accept" class="btn-primary">Accept All Cookies</button>
          <button id="cookie-reject" class="btn-secondary">Reject Non-Essential</button>
          <a href="/privacy" class="cookie-learn-more">Learn More</a>
        </div>
      </div>
    `,document.body.appendChild(e),document.getElementById("cookie-accept").addEventListener("click",()=>this.accept()),document.getElementById("cookie-reject").addEventListener("click",()=>this.reject())}accept(){localStorage.setItem(this.consentKey,"accepted"),this.hideBanner(),this.loadMonetag(),window.activityTracker&&window.activityTracker.track("cookie_consent_accepted",{type:"eu_user"})}reject(){localStorage.setItem(this.consentKey,"rejected"),this.hideBanner(),window.activityTracker&&window.activityTracker.track("cookie_consent_rejected",{type:"eu_user"}),console.log("🍪 Cookie Consent: User rejected non-essential cookies. Monetag ads will not load.")}hideBanner(){const e=document.getElementById("cookie-consent-banner");e&&e.remove()}blockMonetag(){document.addEventListener("DOMContentLoaded",()=>{document.querySelectorAll('script[src*="quge5.com"], script[src*="3nbf4.com"]').forEach(e=>{e.remove(),console.log("🛡️ Cookie Consent: Blocked Monetag script (awaiting consent)")})})}loadMonetag(){if(!document.querySelector('script[src*="quge5.com"]')){const e=document.createElement("script");e.src="https://quge5.com/88/tag.min.js",e.setAttribute("data-zone","271359"),e.async=!0,e.setAttribute("data-cfasync","false"),document.head.appendChild(e),console.log("✅ Cookie Consent: Monetag ads loaded (consent granted or non-EU user)")}}}document.readyState==="loading"?document.addEventListener("DOMContentLoaded",()=>new q):new q,console.log("✅ Meme Explorer bundled - 74→23 JS files")})();
