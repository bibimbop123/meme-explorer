var l=(f,y,c)=>new Promise((m,h)=>{var v=r=>{try{u(c.next(r))}catch(d){h(d)}},w=r=>{try{u(c.throw(r))}catch(d){h(d)}},u=r=>r.done?m(r.value):Promise.resolve(r.value).then(v,w);u((c=c.apply(f,y)).next())});(function(){"use strict";window.handleMediaError=function(n){if(!n.dataset.errorHandled){n.dataset.errorHandled="true";const e=n.dataset.fallback;if(e&&n.src!==e){n.src=e;return}n.src="/images/meme-placeholder.svg",n.alt="Image failed to load",console.warn("Image failed to load:",n.dataset.originalSrc||n.src)}};class f{constructor(){this.currentIndex=0,this.images=[],this.init()}init(){console.log("[MemeDisplay] Initializing..."),this.bindCarouselControls(),this.setupImageErrorHandling()}bindCarouselControls(){const e=document.getElementById("carousel-prev"),o=document.getElementById("carousel-next");e&&e.addEventListener("click",()=>this.showPrevious()),o&&o.addEventListener("click",()=>this.showNext())}setupImageErrorHandling(){const e=document.getElementById("meme-image");e&&e.addEventListener("error",()=>this.handleImageError())}showPrevious(){this.currentIndex>0&&(this.currentIndex--,this.updateDisplay())}showNext(){this.currentIndex<this.images.length-1&&(this.currentIndex++,this.updateDisplay())}updateDisplay(){document.querySelectorAll(".gallery-slide").forEach((o,t)=>{o.classList.toggle("active",t===this.currentIndex)}),document.querySelectorAll(".gallery-dot").forEach((o,t)=>{o.classList.toggle("active",t===this.currentIndex)});const e=document.getElementById("carousel-counter")||document.querySelector(".gallery-counter");e&&this.images.length>1&&(e.textContent=`${this.currentIndex+1} / ${this.images.length}`,e.style.display="block"),console.log(`[MemeDisplay] Showing image ${this.currentIndex+1}/${this.images.length}`)}handleImageError(){console.warn("[MemeDisplay] Image failed to load"),typeof window.showPlaceholder=="function"&&window.showPlaceholder()}}class y{constructor(){this.loading=!1,this.prefetchedMeme=null,this.transitionDuration=140,this.init()}init(){console.log("[MemeNavigation] Initializing AJAX navigation..."),this.bindKeyboardShortcuts(),this.bindNavigationButtons(),this.setupPopStateHandler(),this.prefetchNext()}bindKeyboardShortcuts(){document.addEventListener("keydown",e=>this.handleKeyPress(e))}bindNavigationButtons(){document.querySelectorAll('[data-action="next-meme"], .next-button, #next-btn').forEach(t=>{t.addEventListener("click",s=>{s.preventDefault(),this.loadNextMeme()})}),document.querySelectorAll('[data-action="similar-meme"]').forEach(t=>{t.addEventListener("click",s=>{s.preventDefault();const i=t.dataset.subreddit;i&&this.loadSimilarMeme(i)})})}setupPopStateHandler(){window.addEventListener("popstate",e=>{e.state&&e.state.meme?this.renderMeme(e.state.meme,!1):window.location.reload()})}handleKeyPress(e){if(!this.isInputFocused()&&!e.repeat)switch(e.code){case"Space":case"ArrowRight":e.preventDefault(),this.loadNextMeme();break;case"ArrowLeft":e.preventDefault(),window.history.back();break;case"KeyL":e.preventDefault(),this.triggerLike();break;case"KeyS":e.preventDefault(),this.triggerSave();break;case"KeyT":e.preventDefault(),this.toggleTitle();break}}isInputFocused(){const e=document.activeElement;return e&&(e.tagName==="INPUT"||e.tagName==="TEXTAREA"||e.isContentEditable)}loadNextMeme(){return l(this,null,function*(){if(this.loading){console.log("[MemeNavigation] Already loading, please wait...");return}console.log("[MemeNavigation] Loading next meme via AJAX..."),this.loading=!0;try{this.showLoadingState();let e;if(this.prefetchedMeme)console.log("[MemeNavigation] Using prefetched meme"),e=this.prefetchedMeme,this.prefetchedMeme=null;else{const o=yield fetch("/random.json");if(!o.ok)throw new Error(`HTTP ${o.status}: ${o.statusText}`);e=yield o.json()}yield this.renderMeme(e),this.updateURL(e),this.prefetchNext(),this.trackView(e),console.log("[MemeNavigation] ✅ Meme loaded successfully")}catch(e){console.error("[MemeNavigation] Failed to load meme:",e),this.showError("Failed to load meme. Please try again."),setTimeout(()=>{window.location.href="/random"},2e3)}finally{this.loading=!1,this.hideLoadingState()}})}loadSimilarMeme(e){return l(this,null,function*(){if(!this.loading){console.log(`[MemeNavigation] Loading similar meme from r/${e}...`),this.loading=!0;try{this.showLoadingState();const o=yield fetch(`/similar.json?subreddit=${encodeURIComponent(e)}`);if(!o.ok)throw new Error(`HTTP ${o.status}`);const t=yield o.json();yield this.renderMeme(t),this.updateURL(t),this.prefetchNext(),this.trackView(t)}catch(o){console.error("[MemeNavigation] Failed to load similar meme:",o),this.showError("No similar memes found. Showing random instead."),setTimeout(()=>this.loadNextMeme(),1e3)}finally{this.loading=!1,this.hideLoadingState()}}})}renderMeme(e,o=!0){return l(this,null,function*(){const t=document.querySelector("#meme-display"),s=document.querySelector("#meme-info");if(!t){console.error("[MemeNavigation] #meme-display not found");return}t.classList.remove("meme-transition-in"),t.offsetWidth,t.classList.add("meme-transition-out"),yield this.wait(this.transitionDuration),t.innerHTML=this.renderMemeHTML(e),s&&(s.innerHTML=this.renderInfoHTML(e)),this.updateControlsState(e),t.classList.remove("meme-transition-out"),t.offsetWidth,t.classList.add("meme-transition-in"),this.flashPulse(),o&&this.updateURL(e),window.scrollTo({top:0,behavior:"smooth"})})}renderMemeHTML(e){var o,t;return e.media_type==="video"||(o=e.url)!=null&&o.includes("v.redd.it")?`
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
      `:e.is_gallery&&((t=e.gallery_images)==null?void 0:t.length)>0?this.renderGalleryHTML(e.gallery_images,e.title):`
      <div class="meme-image-container">
        <img 
          src="${this.escapeHtml(e.url)}" 
          alt="${this.escapeHtml(e.title||"Meme")}"
          class="meme-image"
          loading="eager"
          onerror="this.src='/images/meme-placeholder.svg'"
        />
      </div>
    `}renderGalleryHTML(e,o){return`
      <div class="meme-gallery">
        <div class="gallery-container">
          ${e.map((s,i)=>`
      <div class="gallery-slide" data-index="${i}">
        <img 
          src="${this.escapeHtml(s.url||s)}" 
          alt="${this.escapeHtml(o)} - Image ${i+1}"
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
    `}renderInfoHTML(e){const o=this.escapeHtml(e.subreddit||"unknown"),t=this.escapeHtml(e.title||"Untitled Meme"),s=parseInt(e.likes)||0,i=e.diversity_pool||e.selection_method||"random";return`
      <h2 class="meme-title">${t}</h2>
      <div class="meme-meta">
        <span class="meme-subreddit">
          <a href="/category/${o}" title="View more from r/${o}">
            r/${o}
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
    `}updateControlsState(e){const o=document.querySelector(".like-button");o&&(o.classList.remove("liked"),o.dataset.memeUrl=e.url);const t=document.querySelector(".like-count");t&&(t.textContent=e.likes||0);const s=document.querySelector(".save-button");s&&(s.classList.remove("saved"),s.dataset.memeUrl=e.url)}showLoadingState(){const e=document.querySelector("#meme-display");e&&e.classList.add("loading"),document.querySelectorAll(".meme-controls button").forEach(t=>t.disabled=!0)}hideLoadingState(){const e=document.querySelector("#meme-display");e&&e.classList.remove("loading"),document.querySelectorAll(".meme-controls button").forEach(t=>t.disabled=!1)}showError(e){const o=document.querySelector("#meme-display");o&&(o.innerHTML=`
        <div class="error-message">
          <p>⚠️ ${this.escapeHtml(e)}</p>
          <button onclick="location.reload()">Reload Page</button>
        </div>
      `)}updateURL(e){const o={meme:e},t=e.title||"Random Meme",s="/random";try{history.pushState(o,t,s),document.title=`${t} - Meme Explorer`}catch(i){console.warn("[MemeNavigation] Failed to update history:",i)}}prefetchNext(){this.loading||this.prefetchedMeme||(console.log("[MemeNavigation] Prefetching next meme..."),fetch("/random.json").then(e=>e.json()).then(e=>{if(this.prefetchedMeme=e,console.log("[MemeNavigation] ✅ Next meme prefetched"),e.url&&!e.url.includes("v.redd.it")){const o=new Image;o.src=e.url}}).catch(e=>{console.warn("[MemeNavigation] Prefetch failed:",e)}))}trackView(e){typeof gtag!="undefined"&&gtag("event","meme_view",{meme_url:e.url,subreddit:e.subreddit,pool_type:e.diversity_pool||"random"}),typeof window.trackMemeView=="function"&&window.trackMemeView(e)}toggleTitle(){const e=document.querySelector(".meme-title");e&&(e.style.display=e.style.display==="none"?"block":"none")}triggerLike(){const e=document.querySelector(".like-button");e&&e.click()}triggerSave(){const e=document.querySelector(".save-button");e&&e.click()}wait(e){return new Promise(o=>setTimeout(o,e))}flashPulse(){let e=document.querySelector(".meme-flash-pulse");e?(e.style.animation="none",e.offsetWidth,e.style.animation=""):(e=document.createElement("div"),e.className="meme-flash-pulse",document.body.appendChild(e))}escapeHtml(e){const o=document.createElement("div");return o.textContent=e,o.innerHTML}nextGalleryImage(){const e=document.querySelector(".gallery-container");if(!e)return;const o=e.querySelectorAll(".gallery-slide"),t=e.querySelector(".gallery-slide.active")||o[0],i=(parseInt(t.dataset.index)+1)%o.length;this.showGallerySlide(i)}prevGalleryImage(){const e=document.querySelector(".gallery-container");if(!e)return;const o=e.querySelectorAll(".gallery-slide"),t=e.querySelector(".gallery-slide.active")||o[0],s=parseInt(t.dataset.index),i=s===0?o.length-1:s-1;this.showGallerySlide(i)}showGallerySlide(e){const o=document.querySelectorAll(".gallery-slide"),t=document.querySelector(".gallery-counter");o.forEach((s,i)=>{s.classList.toggle("active",i===e)}),t&&(t.textContent=`${e+1} / ${o.length}`)}}class c{constructor(){this.isProcessing=!1,this.init()}init(){console.log("[MemeInteractions] Initializing Production Grade Edition..."),this.bindLikeButton(),this.bindSaveButton(),this.bindShareButton(),this.checkInitialStates(),this.addAnimationStyles()}addAnimationStyles(){if(document.getElementById("meme-interactions-styles"))return;const e=document.createElement("style");e.id="meme-interactions-styles",e.textContent=`
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
    `,document.head.appendChild(e)}bindLikeButton(){const e=document.getElementById("like-btn");e&&e.addEventListener("click",o=>this.handleLike(o))}bindSaveButton(){const e=document.getElementById("save-btn");e&&e.addEventListener("click",o=>this.handleSave(o))}bindShareButton(){const e=document.getElementById("share-btn");e&&e.addEventListener("click",()=>this.handleShare())}createRipple(e){const o=e.currentTarget,t=document.createElement("span");t.className="ripple-effect";const s=o.getBoundingClientRect(),i=Math.max(s.width,s.height),a=e.clientX-s.left-i/2,p=e.clientY-s.top-i/2;t.style.width=t.style.height=`${i}px`,t.style.left=`${a}px`,t.style.top=`${p}px`,o.style.position="relative",o.style.overflow="hidden",o.appendChild(t),setTimeout(()=>t.remove(),600)}triggerHaptic(e="medium"){if("vibrate"in navigator){const o={light:[10],medium:[20],heavy:[30],success:[10,50,10]};navigator.vibrate(o[e]||o.medium)}}handleLike(e){return l(this,null,function*(){if(this.isProcessing)return;console.log("[MemeInteractions] Like clicked"),this.createRipple(e);const o=this.getCurrentMemeUrl();if(!o){console.error("[MemeInteractions] No meme URL found");return}const t=document.getElementById("like-btn"),s=t==null?void 0:t.classList.contains("liked");this.isProcessing=!0,t==null||t.classList.add("btn-processing"),this.updateLikeButton(!s,!0),this.triggerHaptic(s?"light":"success");try{const i=yield fetch("/like",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({url:o})});if(i.ok){const a=yield i.json();console.log("[MemeInteractions] Like success:",a),this.updateLikeButton(a.liked,!1),this.showToast(a.liked?"❤️ Liked!":"Unliked","success"),a.likes!==void 0&&this.updateLikeCount(a.likes)}else{this.updateLikeButton(s,!1);const a=yield i.json();console.error("[MemeInteractions] Like failed:",a),this.showToast(a.error||"Error liking meme","error"),this.triggerHaptic("heavy")}}catch(i){this.updateLikeButton(s,!1),console.error("[MemeInteractions] Like request failed:",i),this.showToast("Network error","error"),this.triggerHaptic("heavy")}finally{this.isProcessing=!1,t==null||t.classList.remove("btn-processing")}})}handleSave(e){return l(this,null,function*(){var p,I;if(this.isProcessing)return;console.log("[MemeInteractions] Save clicked"),this.createRipple(e);const o=this.getCurrentMemeUrl();if(!o){console.error("[MemeInteractions] No meme URL found");return}const t=document.getElementById("save-btn"),s=t==null?void 0:t.classList.contains("saved"),i=((p=document.querySelector(".meme-title"))==null?void 0:p.textContent)||"Untitled Meme",a=((I=document.querySelector(".meme-subreddit"))==null?void 0:I.textContent)||"unknown";this.isProcessing=!0,t==null||t.classList.add("btn-processing"),this.updateSaveButton(!s,!0),this.triggerHaptic(s?"light":"success");try{const b=yield fetch(s?"/api/unsave-meme":"/api/save-meme",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(s?{url:o}:{url:o,title:i,subreddit:a})});if(b.ok){const g=yield b.json();console.log("[MemeInteractions] Save success:",g),this.updateSaveButton(!s,!1),this.showToast(s?"Removed from saved":"🔖 Saved to profile!","success")}else{this.updateSaveButton(s,!1);const g=yield b.json();console.error("[MemeInteractions] Save failed:",g),this.showToast(g.error||"Error saving meme","error"),this.triggerHaptic("heavy")}}catch(x){this.updateSaveButton(s,!1),console.error("[MemeInteractions] Save request failed:",x),this.showToast("Network error","error"),this.triggerHaptic("heavy")}finally{this.isProcessing=!1,t==null||t.classList.remove("btn-processing")}})}handleShare(){console.log("[MemeInteractions] Share clicked"),this.triggerHaptic("medium"),navigator.share?navigator.share({title:document.title,url:window.location.href}).then(()=>{this.showToast("Shared!","success")}).catch(e=>{e.name!=="AbortError"&&console.log("Share cancelled",e)}):navigator.clipboard.writeText(window.location.href).then(()=>{this.showToast("📤 Link copied!","success"),this.triggerHaptic("success")})}getCurrentMemeUrl(){const e=document.getElementById("meme-image");return e?e.src:null}updateLikeButton(e,o=!0){const t=document.getElementById("like-btn");if(t){o&&e&&(t.classList.add("btn-liked"),setTimeout(()=>t.classList.remove("btn-liked"),600)),t.classList.toggle("liked",e),t.setAttribute("aria-pressed",e);const s=t.querySelector("i, svg");s&&(s.style.color=e?"#e74c3c":"")}}updateSaveButton(e,o=!0){const t=document.getElementById("save-btn");if(t){o&&e&&(t.classList.add("btn-saved"),setTimeout(()=>t.classList.remove("btn-saved"),500)),t.classList.toggle("saved",e),t.setAttribute("aria-pressed",e);const s=t.querySelector("i, svg");s&&(s.style.color=e?"#f39c12":"")}}updateLikeCount(e){const o=document.getElementById("like-count");o&&(o.textContent=e,o.style.transform="scale(1.2)",setTimeout(()=>{o.style.transform="scale(1)"},200))}checkInitialStates(){const e=document.getElementById("like-btn"),o=document.getElementById("save-btn");e&&e.dataset.liked==="true"&&this.updateLikeButton(!0),o&&o.dataset.saved==="true"&&this.updateSaveButton(!0)}showToast(e,o="info"){document.querySelectorAll(".toast-notification").forEach(i=>i.remove());const t=document.createElement("div");t.className="toast-notification",t.textContent=e,t.setAttribute("role","status"),t.setAttribute("aria-live","polite");const s={success:"rgba(39, 174, 96, 0.95)",error:"rgba(231, 76, 60, 0.95)",info:"rgba(52, 73, 94, 0.95)"};t.style.cssText=`
      position: fixed;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: ${s[o]||s.info};
      color: white;
      padding: 12px 24px;
      border-radius: 8px;
      z-index: 10000;
      font-size: 14px;
      font-weight: 500;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      transition: transform 0.2s ease;
      animation: fadeIn 0.3s, fadeOut 0.3s 2.7s;
    `,document.body.appendChild(t),t.addEventListener("mouseenter",()=>{t.style.transform="translateX(-50%) translateY(-4px)"}),t.addEventListener("mouseleave",()=>{t.style.transform="translateX(-50%) translateY(0)"}),setTimeout(()=>{t.style.opacity="0",setTimeout(()=>t.remove(),300)},3e3)}}class m{constructor(){this.display=null,this.navigation=null,this.interactions=null,this.tracking=null,this.prefetch=null,this.init()}init(){return l(this,null,function*(){console.log("[MemeApp] Initializing..."),this.display=new f,this.navigation=new y,this.interactions=new c,console.log("[MemeApp] Initialized successfully"),window.location.hostname==="localhost"&&(window.memeApp=this)})}}document.readyState==="loading"?document.addEventListener("DOMContentLoaded",()=>new m):new m,document.addEventListener("DOMContentLoaded",function(){h(),T()});function h(){document.querySelectorAll(".meme-container, .meme-detail, .meme-card").forEach(e=>{e.querySelector(".share-bar")||v(e)})}function v(n){var s;const e=n.dataset.url||window.location.href,o=n.dataset.title||document.title;(s=n.querySelector("img"))!=null&&s.src;const t=document.createElement("div");t.className="share-bar",t.innerHTML=`
    <button class="share-btn whatsapp" onclick="shareToWhatsApp('${encodeURIComponent(o)}', '${encodeURIComponent(e)}')">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
        <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
      </svg>
      WhatsApp
    </button>
    
    <button class="share-btn twitter" onclick="shareToTwitter('${encodeURIComponent(o)}', '${encodeURIComponent(e)}')">
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
  `,n.appendChild(t)}function w(n,e){const o=`Check out this meme! ${n}`,t=`https://wa.me/?text=${encodeURIComponent(o+" "+e)}`;window.open(t,"_blank"),typeof trackEvent=="function"&&trackEvent("share","whatsapp",n)}function u(n,e){const o=`https://twitter.com/intent/tweet?text=${encodeURIComponent(n)}&url=${encodeURIComponent(e)}&hashtags=memes`;window.open(o,"_blank","width=550,height=420"),typeof trackEvent=="function"&&trackEvent("share","twitter",n)}function r(n){navigator.clipboard&&window.isSecureContext?navigator.clipboard.writeText(n).then(()=>{E()}).catch(e=>{d(n)}):d(n),typeof trackEvent=="function"&&trackEvent("share","copy_link",n)}function d(n){const e=document.createElement("textarea");e.value=n,e.style.position="fixed",e.style.left="-999999px",e.style.top="-999999px",document.body.appendChild(e),e.focus(),e.select();try{document.execCommand("copy"),E()}catch(o){console.error("Failed to copy:",o),alert("Failed to copy link. Please copy manually: "+n)}document.body.removeChild(e)}function E(){const n=document.createElement("div");n.className="copy-toast",n.textContent="✓ Link copied to clipboard!",document.body.appendChild(n),setTimeout(()=>n.classList.add("show"),10),setTimeout(()=>{n.classList.remove("show"),setTimeout(()=>document.body.removeChild(n),300)},3e3)}function T(){document.querySelectorAll(".meme-actions").forEach(n=>{if(!n.querySelector(".share-btn")){const e=document.createElement("button");e.className="btn share-btn-primary",e.innerHTML="🔗 Share This Meme",e.onclick=function(){r(window.location.href)},n.appendChild(e)}})}function C(n,e,o){navigator.share?navigator.share({title:n,text:o||n,url:e}).then(()=>{typeof trackEvent=="function"&&trackEvent("share","native",n)}).catch(t=>console.log("Error sharing:",t)):r(e)}window.shareToWhatsApp=w,window.shareToTwitter=u,window.copyLink=r,window.nativeShare=C;class S{constructor(e){this.moduleName=e,this.errors=[]}wrap(e){return(...o)=>{try{return e(...o)}catch(t){return this.handleError(t),null}}}wrapAsync(e){return l(this,null,function*(){return(...o)=>l(this,null,function*(){try{return yield e(...o)}catch(t){return this.handleError(t),null}})})}handleError(e){console.error(`[${this.moduleName}] Error:`,e),window.AppLogger&&window.AppLogger.error({module:this.moduleName,error:e.message,stack:e.stack}),this.errors.push({timestamp:new Date,error:e.message,stack:e.stack}),this.showUserMessage()}showUserMessage(){if(sessionStorage.getItem(`error_shown_${this.moduleName}`))return;const e=`We encountered an issue with ${this.moduleName}. Please refresh the page.`;window.showToast?window.showToast(e,"error"):console.warn(e),sessionStorage.setItem(`error_shown_${this.moduleName}`,"true")}getErrors(){return this.errors}}typeof module!="undefined"&&module.exports?module.exports=S:window.ErrorBoundary=S,"serviceWorker"in navigator&&!sessionStorage.getItem("sw-refresh-done")&&navigator.serviceWorker.getRegistrations().then(function(n){if(n.length===0){sessionStorage.setItem("sw-refresh-done","1");return}Promise.all(n.map(function(e){return e.unregister().then(function(o){console.log("[SW] Unregistered old service worker:",o)})})).then(function(){sessionStorage.setItem("sw-refresh-done","1"),console.log("[SW] Reloading once to register fresh service worker..."),window.location.reload()})});function B(){const n=document.querySelector(".mobile-nav");n&&n.classList.toggle("open")}function L(n){document.documentElement.setAttribute("data-theme",n),localStorage.setItem("theme",n)}function k(){const n=localStorage.getItem("theme")||"light";L(n)}document.readyState==="loading"?document.addEventListener("DOMContentLoaded",k):k(),typeof module!="undefined"&&module.exports&&(module.exports={toggleMobileNav:B,setTheme:L,initTheme:k});class M{constructor(){this.consentKey="meme_explorer_cookie_consent",this.consentValue=localStorage.getItem(this.consentKey),this.isEU=this.detectEUUser(),this.isEU&&!this.consentValue?(this.showBanner(),this.blockMonetag()):(this.consentValue==="accepted"||!this.isEU)&&this.loadMonetag()}detectEUUser(){const e=["Europe/London","Europe/Paris","Europe/Berlin","Europe/Rome","Europe/Madrid","Europe/Amsterdam","Europe/Brussels","Europe/Vienna","Europe/Stockholm","Europe/Warsaw","Europe/Prague","Europe/Budapest","Europe/Athens","Europe/Lisbon","Europe/Dublin","Europe/Helsinki","Europe/Copenhagen","Europe/Bucharest","Europe/Sofia","Europe/Zagreb","Europe/Vilnius","Europe/Riga","Europe/Tallinn","Europe/Ljubljana","Europe/Bratislava","Europe/Luxembourg","Europe/Valletta","Europe/Nicosia"];try{const o=Intl.DateTimeFormat().resolvedOptions().timeZone;return e.includes(o)}catch(o){return console.warn("Cookie Consent: Could not detect timezone, assuming non-EU"),!1}}showBanner(){const e=document.createElement("div");e.id="cookie-consent-banner",e.innerHTML=`
      <div class="cookie-consent-content">
        <p><strong>🍪 This Site Uses Cookies</strong></p>
        <p>We and our advertising partners (Monetag/PropellerAds, Google AdSense) use cookies and similar technologies to personalize content and ads, provide social media features, and analyze our traffic. By clicking "Accept", you consent to our use of cookies.</p>
        <div class="cookie-consent-buttons">
          <button id="cookie-accept" class="btn-primary">Accept All Cookies</button>
          <button id="cookie-reject" class="btn-secondary">Reject Non-Essential</button>
          <a href="/privacy" class="cookie-learn-more">Learn More</a>
        </div>
      </div>
    `,document.body.appendChild(e),document.getElementById("cookie-accept").addEventListener("click",()=>this.accept()),document.getElementById("cookie-reject").addEventListener("click",()=>this.reject())}accept(){localStorage.setItem(this.consentKey,"accepted"),this.hideBanner(),this.loadMonetag(),window.activityTracker&&window.activityTracker.track("cookie_consent_accepted",{type:"eu_user"})}reject(){localStorage.setItem(this.consentKey,"rejected"),this.hideBanner(),window.activityTracker&&window.activityTracker.track("cookie_consent_rejected",{type:"eu_user"}),console.log("🍪 Cookie Consent: User rejected non-essential cookies. Monetag ads will not load.")}hideBanner(){const e=document.getElementById("cookie-consent-banner");e&&e.remove()}blockMonetag(){document.addEventListener("DOMContentLoaded",()=>{document.querySelectorAll('script[src*="quge5.com"], script[src*="3nbf4.com"]').forEach(e=>{e.remove(),console.log("🛡️ Cookie Consent: Blocked Monetag script (awaiting consent)")})})}loadMonetag(){if(!document.querySelector('script[src*="quge5.com"]')){const e=document.createElement("script");e.src="https://quge5.com/88/tag.min.js",e.setAttribute("data-zone","271359"),e.async=!0,e.setAttribute("data-cfasync","false"),document.head.appendChild(e),console.log("✅ Cookie Consent: Monetag ads loaded (consent granted or non-EU user)")}}}document.readyState==="loading"?document.addEventListener("DOMContentLoaded",()=>new M):new M,console.log("✅ Meme Explorer bundled - 74→23 JS files")})();
