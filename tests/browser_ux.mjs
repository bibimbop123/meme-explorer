// Dependency-free Chrome DevTools acceptance. Start guarded browser_fixture.ru,
// then Chrome with a disposable profile and loopback remote debugging port 19293.
import assert from 'node:assert/strict';

const origin = 'http://127.0.0.1:19292';
const targets = await (await fetch('http://127.0.0.1:19293/json/list')).json();
const target = targets.find(item => item.type === 'page');
assert.ok(target, 'Chrome page target required');
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => { ws.addEventListener('open', resolve, { once: true }); ws.addEventListener('error', reject, { once: true }); });
let nextId = 0;
const pending = new Map();
const exceptions = [];
let nextFixture = null;
let videoBytes = null;
ws.addEventListener('message', event => {
  const message = JSON.parse(event.data);
  if (message.id) {
    const item = pending.get(message.id);
    if (!item) return;
    clearTimeout(item.timer);
    pending.delete(message.id);
    message.error ? item.reject(new Error(JSON.stringify(message.error))) : item.resolve(message.result);
  } else if (message.method === 'Runtime.exceptionThrown') exceptions.push(message.params.exceptionDetails.text);
});
const send = (method, params = {}) => new Promise((resolve, reject) => {
  const id = ++nextId;
  const timer = setTimeout(() => { pending.delete(id); reject(new Error(`Timeout: ${method}`)); }, 10000);
  pending.set(id, { resolve, reject, timer });
  ws.send(JSON.stringify({ id, method, params }));
});
const evaluate = async expression => {
  const result = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  assert.equal(result.exceptionDetails, undefined, JSON.stringify(result.exceptionDetails));
  return result.result.value;
};
const wait = async expression => {
  for (let i = 0; i < 80; i++) {
    if (await evaluate(expression)) return;
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  throw new Error(`Condition timeout: ${expression}`);
};
const check = (label, value) => { assert.ok(value, label); console.log(`PASS: ${label}`); };
const key = async (key, code = key, modifiers = 0) => {
  await send('Input.dispatchKeyEvent', { type: 'keyDown', key, code, modifiers,
    ...(key === 'Enter' ? { text: '\r', unmodifiedText: '\r', windowsVirtualKeyCode: 13 } : {}) });
  await send('Input.dispatchKeyEvent', { type: 'keyUp', key, code, modifiers });
};
try {
  await send('Page.enable');
  await send('Runtime.enable');
  await send('Network.enable');
  // Interception blocks every non-fixture origin before navigation.
  await send('Fetch.enable', { patterns: [{ urlPattern: '*' }] });
  ws.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (message.method !== 'Fetch.requestPaused') return;
    const { requestId, request } = message.params;
    if (request.url === `${origin}/videos/browser-generated.webm` && videoBytes) {
      const bytes = Buffer.from(videoBytes, 'base64');
      const range = Object.entries(request.headers).find(([name]) => name.toLowerCase() === 'range')?.[1];
      const match = range?.match(/^bytes=(\d+)-(\d*)$/);
      const start = match ? Number(match[1]) : 0;
      const end = match && match[2] ? Math.min(Number(match[2]), bytes.length - 1) : bytes.length - 1;
      const headers = [{ name: 'Content-Type', value: 'video/webm' }, { name: 'Accept-Ranges', value: 'bytes' }];
      if (match) headers.push({ name: 'Content-Range', value: `bytes ${start}-${end}/${bytes.length}` });
      send('Fetch.fulfillRequest', { requestId, responseCode: match ? 206 : 200,
        responseHeaders: headers, body: bytes.subarray(start, end + 1).toString('base64') }).catch(() => {});
      return;
    }
    if (request.url.startsWith(`${origin}/random.json`) && nextFixture) {
      const fixture = nextFixture;
      nextFixture = null;
      send('Fetch.fulfillRequest', { requestId, responseCode: 200,
        responseHeaders: [{ name: 'Content-Type', value: 'application/json' }],
        body: Buffer.from(JSON.stringify(fixture)).toString('base64') }).catch(() => {});
      return;
    }
    const allowed = request.url.startsWith(`${origin}/`) || request.url.startsWith('data:');
    send(allowed ? 'Fetch.continueRequest' : 'Fetch.failRequest', allowed ? { requestId } : { requestId, errorReason: 'BlockedByClient' }).catch(() => {});
  });
  await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 2 });
  for (const width of [320, 375, 1280]) {
    await send('Emulation.setDeviceMetricsOverride', { width, height: 900, deviceScaleFactor: 1, mobile: false });
    await send('Page.navigate', { url: `${origin}/random` });
    await wait(`document.querySelector('#meme-image')?.naturalWidth > 0 && !!window.mobileSwipe`);
    await evaluate(`document.querySelector('.skip-to-content').focus()`);
    const skipIdentity = await evaluate(`document.querySelector('#meme-display').dataset.memeUrl`);
    check(`${width}px: focused skip link is visible within viewport`, await evaluate(`(() => { const link=document.querySelector('.skip-to-content');const r=link.getBoundingClientRect();const s=getComputedStyle(link);return r.width>0 && r.height>0 && r.top>=0 && r.bottom<=innerHeight && s.visibility!=='hidden' && s.opacity!=='0'; })()`));
    await key('Enter');
    check(`${width}px: skip link transfers focus to main content`, await evaluate(`document.activeElement.id === 'main-content'`));
    check(`${width}px: skip preserves meme and history URL`, await evaluate(`location.hash === '' && document.querySelector('#meme-display').dataset.memeUrl === ${JSON.stringify(skipIdentity)}`));
    await key('Tab');
    check(`${width}px: Tab after skip reaches viewer navigation`, await evaluate(`document.activeElement.closest('.viewer-navigation') !== null`));
    check(`${width}px: no horizontal page overflow`, await evaluate('document.documentElement.scrollWidth <= innerWidth + 1'));
    check(`${width}px: decoded image remains within viewer`, await evaluate(`(() => { const image = document.querySelector('#meme-image').getBoundingClientRect(); const viewer = document.querySelector('#meme-display').getBoundingClientRect(); return image.width > 0 && image.left >= viewer.left - 1 && image.right <= viewer.right + 1; })()`));
    for (const theme of ['dark', 'light']) {
      await evaluate(`if(document.documentElement.dataset.theme !== '${theme}') document.querySelector('#darkModeToggle').click()`);
      check(`${width}px: ${theme} state synchronized`, await evaluate(`document.documentElement.dataset.theme === '${theme}' && document.querySelector('#darkModeToggle').getAttribute('aria-pressed') === '${theme === 'dark'}'`));
      for (const id of ['like-btn', 'save-btn', 'share-btn', 'download-btn']) {
        if (id === 'like-btn') await evaluate(`document.getElementById('like-btn').focus()`);
        else await key('Tab');
        await new Promise(resolve => setTimeout(resolve, 100));
        check(`${width}px ${theme}: ${id} has visible keyboard focus`, await evaluate(`(() => {const b=document.activeElement;const s=getComputedStyle(b);return b.id===${JSON.stringify(id)} && b.matches(':focus-visible') && s.outlineStyle!=='none' && parseFloat(s.outlineWidth)>=2;})()`));
        check(`${width}px ${theme}: ${id} is within viewport and unobscured`, await evaluate(`(() => {const b=document.activeElement;const r=b.getBoundingClientRect();const hit=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);return r.left>=0 && r.right<=innerWidth+1 && r.top>=0 && r.bottom<=innerHeight+1 && (hit===b || b.contains(hit));})()`));
      }
    }
    await evaluate(`document.querySelector('#menuToggle').focus()`);
    await new Promise(resolve => setTimeout(resolve, 150));
    await evaluate(`document.querySelector('#menuToggle').click()`);
    check(`${width}px: menu opens within viewport`, await evaluate(`(() => {const m=document.querySelector('#hamburgerMenu');const r=m.getBoundingClientRect();return !m.hidden && r.left>=0 && r.right<=innerWidth+1 && r.bottom<=innerHeight+1;})()`));
    await key('Escape');
    check(`${width}px: Escape closes menu and restores focus`, await evaluate(`document.querySelector('#hamburgerMenu').hidden && document.activeElement.id==='menuToggle'`));
    await evaluate(`document.activeElement.blur()`);
    await key('?', 'Slash', 8);
    check(`${width}px: shortcuts dialog receives focus`, await evaluate(`document.querySelector('#keyboard-shortcuts-modal').getAttribute('aria-hidden')==='false' && document.activeElement.classList.contains('modal-close')`));
    await key('Tab');
    check(`${width}px: dialog retains keyboard focus`, await evaluate(`document.querySelector('#keyboard-shortcuts-modal').contains(document.activeElement)`));
    await key('Escape');
    check(`${width}px: shortcuts dialog dismisses`, await evaluate(`document.querySelector('#keyboard-shortcuts-modal').getAttribute('aria-hidden')==='true'`));
    const before = await evaluate(`document.querySelector('#meme-display').dataset.memeUrl`);
    await evaluate(`document.querySelector('#next-btn').focus()`);
    await key(' ', 'Space');
    await wait(`document.querySelector('#meme-display').dataset.memeUrl !== ${JSON.stringify(before)} && document.querySelector('#meme-image')?.naturalWidth > 0`);
    check(`${width}px: Space advances to another decoded meme`, true);
    await evaluate(`document.querySelector('#prev-btn').click()`);
    await wait(`document.querySelector('#meme-display').dataset.memeUrl === ${JSON.stringify(before)}`);
    check(`${width}px: Previous restores exact media identity`, true);
    await evaluate(`document.documentElement.style.fontSize='32px'`);
    check(`${width}px: enlarged root text does not overflow page`, await evaluate('document.documentElement.scrollWidth <= innerWidth + 1'));
    await evaluate(`document.documentElement.style.fontSize=''`);
  }
  await send('Emulation.setDeviceMetricsOverride', { width: 375, height: 900, deviceScaleFactor: 1, mobile: true });
  await send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-reduced-motion', value: 'reduce' }] });
  await send('Page.navigate', { url: `${origin}/random` });
  await wait(`document.querySelector('#meme-image')?.naturalWidth > 0 && !!window.mobileSwipe`);
  check('reduced-motion preference reaches browser', await evaluate(`matchMedia('(prefers-reduced-motion: reduce)').matches`));
  await evaluate(`document.querySelector('#meme-image').scrollIntoView({block:'center'})`);
  const bounds = await evaluate(`document.querySelector('#meme-image').getBoundingClientRect().toJSON()`);
  const y = Math.max(160, Math.min(650, bounds.top + bounds.height / 2));
  const touch = async (type, x, y) => send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
  let identity = await evaluate(`document.querySelector('#meme-display').dataset.memeUrl`);
  await touch('touchStart', 250, y);
  await touch('touchMove', 240, y - 100);
  await touch('touchEnd', 240, y - 100);
  await new Promise(resolve => setTimeout(resolve, 400));
  check('vertical touch scroll preserves current meme', await evaluate(`document.querySelector('#meme-display').dataset.memeUrl === ${JSON.stringify(identity)}`));
  await evaluate(`document.querySelector('#meme-image').scrollIntoView({block:'center'})`);
  const swipeY = await evaluate(`(() => {const r=document.querySelector('#meme-image').getBoundingClientRect();return Math.max(160,Math.min(650,r.top+r.height/2));})()`);
  await touch('touchStart', 280, swipeY);
  await touch('touchMove', 90, swipeY);
  await touch('touchEnd', 90, swipeY);
  await wait(`document.querySelector('#meme-display').dataset.memeUrl !== ${JSON.stringify(identity)}`);
  check('horizontal touch swipe advances viewer', true);
  await send('Page.navigate', { url: `${origin}/about` });
  await wait(`document.readyState === 'complete' && !!window.mobileSwipe`);
  check('nonviewer page does not initialize swipe overlay', await evaluate(`!document.querySelector('#swipe-overlay')`));
  await touch('touchStart', 280, 350);
  await touch('touchMove', 90, 350);
  await touch('touchEnd', 90, 350);
  await new Promise(resolve => setTimeout(resolve, 300));
  check('horizontal touch on About does not redirect to feed', await evaluate(`location.pathname === '/about'`));
  await send('Page.navigate', { url: `${origin}/random?fixture_media=gallery` });
  await wait(`document.querySelector('.gallery-carousel')?.dataset.carouselReady === 'true' && document.querySelector('.gallery-slide.active img')?.naturalWidth > 0 && !!window.mobileSwipe`);
  identity = await evaluate(`document.querySelector('#meme-display').dataset.memeUrl`);
  await evaluate(`document.querySelector('.gallery-next').click()`);
  check('server gallery Next changes slide exactly once', await evaluate(`document.querySelector('.gallery-slide.active').dataset.index === '1'`));
  const galleryTree = await send('Accessibility.getFullAXTree');
  check('server gallery exposes only current image to accessibility tree', galleryTree.nodes.filter(node => !node.ignored && node.role?.value === 'image' && node.name?.value?.includes('Browser gallery fixture')).length === 1);
  check('gallery position is a live status', await evaluate(`document.querySelector('.gallery-counter').getAttribute('role') === 'status'`));
  check('gallery indicators are keyboard buttons with selected state', await evaluate(`Array.from(document.querySelectorAll('.gallery-dot')).every(dot => dot.tagName === 'BUTTON' && dot.hasAttribute('aria-pressed'))`));
  await evaluate(`document.querySelector('.gallery-dot[data-index="0"]').focus()`);
  await key('Enter');
  check('gallery indicator activates with Enter and updates selected state', await evaluate(`document.querySelector('.gallery-slide.active').dataset.index === '0' && document.querySelector('.gallery-dot[data-index="0"]').getAttribute('aria-pressed') === 'true'`));
  check('keyboard indicator has visible focus outline', await evaluate(`getComputedStyle(document.activeElement).outlineStyle !== 'none' && parseFloat(getComputedStyle(document.activeElement).outlineWidth) >= 2`));
  check('gallery transition respects reduced motion', await evaluate(`getComputedStyle(document.querySelector('.gallery-slide.active')).transitionDuration === '0s'`));
  await evaluate(`document.querySelector('.gallery-next').click()`);
  await evaluate(`document.activeElement.blur()`);
  await key('ArrowRight');
  check('gallery arrow key changes slide without changing meme', await evaluate(`document.querySelector('.gallery-slide.active').dataset.index === '2' && document.querySelector('#meme-display').dataset.memeUrl === ${JSON.stringify(identity)}`));
  await evaluate(`document.querySelector('.gallery-prev').click(); document.querySelector('.gallery-carousel').scrollIntoView({block:'center'})`);
  const galleryY = await evaluate(`(() => {const r=document.querySelector('.gallery-slide.active img').getBoundingClientRect();return Math.max(180,Math.min(550,r.top+r.height/2));})()`);
  await touch('touchStart', 280, galleryY);
  await touch('touchMove', 200, galleryY - 180);
  await touch('touchEnd', 200, galleryY - 180);
  check('vertical-dominant gallery touch preserves slide', await evaluate(`document.querySelector('.gallery-slide.active').dataset.index === '1'`));
  check('gallery touch never advances feed', await evaluate(`document.querySelector('#meme-display').dataset.memeUrl === ${JSON.stringify(identity)}`));
  await send('Page.navigate', { url: `${origin}/random?fixture_media=video` });
  await wait(`!!document.querySelector('video') && !!document.querySelector('[data-media-recovery]')`);
  identity = await evaluate(`document.querySelector('#meme-display').dataset.memeUrl`);
  check('video exposes native controls and stays muted', await evaluate(`document.querySelector('video').controls && document.querySelector('video').muted`));
  check('invalid video exposes explicit retry and next actions', await evaluate(`!!document.querySelector('[data-media-action="retry"]') && !!document.querySelector('[data-media-action="next"]')`));
  await evaluate(`document.querySelector('[data-media-action="retry"]').click()`);
  await wait(`document.querySelector('[data-media-recovery] p')?.textContent.includes('Still not loading')`);
  check('failed video retry preserves exact identity', await evaluate(`document.querySelector('#meme-display').dataset.memeUrl === ${JSON.stringify(identity)}`));
  await evaluate(`document.querySelector('[data-media-action="next"]').click()`);
  await wait(`document.querySelector('#meme-image')?.naturalWidth > 0`);
  check('video failure offers working next-meme escape', true);
  // Generate original synthetic media in Chrome, avoiding network downloads,
  // new codec libraries or mislabeled repository placeholder videos.
  videoBytes = await evaluate(`(async () => {
    const canvas = document.createElement('canvas'); canvas.width=160; canvas.height=120;
    const context = canvas.getContext('2d');
    const stream = canvas.captureStream(10);
    const recorder = new MediaRecorder(stream, {mimeType:'video/webm;codecs=vp8'});
    const chunks=[]; recorder.ondataavailable=e=>{if(e.data.size)chunks.push(e.data)};
    const done=new Promise(resolve=>recorder.onstop=resolve);
    recorder.start();
    for(let i=0;i<20;i++){context.fillStyle=i%2?'#2255aa':'#aa5522';context.fillRect(0,0,160,120);await new Promise(r=>setTimeout(r,100));}
    recorder.stop();await done;stream.getTracks().forEach(t=>t.stop());
    const bytes=new Uint8Array(await new Blob(chunks,{type:'video/webm'}).arrayBuffer());
    return btoa(String.fromCharCode(...bytes));
  })()`);
  check('original synthetic video fixture generated', videoBytes.length > 100);
  // Reload an image page; its first prefetch receives the controlled JSON fixture.
  nextFixture = {url:'/images/funny1.jpeg?dynamic-gallery',title:'Dynamic gallery fixture',subreddit:'local',
    is_gallery:true,media_type:'image',gallery_images:[{url:'/images/funny1.jpeg'},{url:'/images/funny2.jpeg'},{url:'/images/funny3.jpeg'}]};
  await send('Page.navigate', {url:`${origin}/random`});
  await wait(`document.querySelector('#meme-image')?.naturalWidth > 0 && !!window.mobileSwipe`);
  await new Promise(resolve=>setTimeout(resolve,300));
  await evaluate(`document.querySelector('#next-btn').click()`);
  await wait(`!!document.querySelector('.meme-gallery') && document.querySelector('.gallery-slide.active img')?.naturalWidth > 0`);
  check('JSON gallery renders decoded first slide',true);
  await evaluate(`document.querySelector('.gallery-next').click()`);
  check('dynamic gallery advances once',await evaluate(`document.querySelector('.gallery-slide.active').dataset.index==='1'`));
  identity=await evaluate(`document.querySelector('#meme-display').dataset.memeUrl`);
  await evaluate(`document.querySelector('.gallery-slide.active img').scrollIntoView({block:'center'})`);
  const dynamicY = await evaluate(`(() => {const r=document.querySelector('.gallery-slide.active img').getBoundingClientRect();return Math.max(180,Math.min(550,r.top+r.height/2));})()`);
  await touch('touchStart',280,dynamicY);
  await touch('touchMove',200,dynamicY-180);
  await touch('touchEnd',200,dynamicY-180);
  check('dynamic gallery vertical touch preserves slide',await evaluate(`document.querySelector('.gallery-slide.active').dataset.index==='1'`));
  await evaluate(`document.querySelector('.gallery-slide.active img').scrollIntoView({block:'center'})`);
  const horizontalY = await evaluate(`(() => {const r=document.querySelector('.gallery-slide.active img').getBoundingClientRect();return Math.max(180,Math.min(550,r.top+r.height/2));})()`);
  await touch('touchStart',280,horizontalY);
  await touch('touchMove',90,horizontalY);
  await touch('touchEnd',90,horizontalY);
  check('dynamic gallery horizontal touch changes slide not feed',await evaluate(`document.querySelector('.gallery-slide.active').dataset.index==='2' && document.querySelector('#meme-display').dataset.memeUrl===${JSON.stringify(identity)}`));
  await evaluate(`document.querySelector('.gallery-prev').click()`);
  await evaluate(`document.querySelector('#next-btn').click()`);
  await wait(`!!document.querySelector('#meme-image')`);
  await evaluate(`document.querySelector('#prev-btn').click()`);
  await wait(`!!document.querySelector('.meme-gallery')`);
  check('Previous restores dynamic gallery slide and identity',await evaluate(`document.querySelector('.gallery-slide.active').dataset.index==='1' && document.querySelector('#meme-display').dataset.memeUrl===${JSON.stringify(identity)}`));
  nextFixture={url:'/videos/browser-generated.webm',title:'Synthetic video fixture',subreddit:'local',media_type:'video'};
  await send('Page.navigate',{url:`${origin}/random`});
  await wait(`document.querySelector('#meme-image')?.naturalWidth > 0 && !!window.mobileSwipe`);
  await new Promise(resolve=>setTimeout(resolve,300));
  await evaluate(`document.querySelector('#next-btn').click()`);
  await wait(`document.querySelector('video')?.readyState >= 2`);
  check('dynamic video decodes with native controls',await evaluate(`document.querySelector('video').controls && !document.querySelector('video').error`));
  await evaluate(`document.querySelector('video').play()`);
  await wait(`document.querySelector('video').currentTime > 0.2`);
  check('valid video playback advances time',true);
  await evaluate(`(() => { const video=document.querySelector('video');video.pause();video.currentTime=0.8; })()`);
  await wait(`Math.abs(document.querySelector('video').currentTime-0.8)<0.15 && !document.querySelector('video').seeking`);
  check('valid video seeks and remains muted',await evaluate(`document.querySelector('video').muted && document.querySelector('video').paused`));
  await evaluate(`document.querySelector('#next-btn').click()`);
  await wait(`!!document.querySelector('#meme-image')`);
  await evaluate(`document.querySelector('#prev-btn').click()`);
  await wait(`document.querySelector('video')?.readyState>=2 && Math.abs(document.querySelector('video').currentTime-0.8)<0.2`);
  check('Previous restores video playback position',true);
  await send('Page.navigate', {url:`${origin}/random`});
  await wait(`document.querySelector('#meme-image')?.naturalWidth > 0 && !!window.mobileSwipe`);
  await evaluate(`(() => {
    const original = window.fetch;
    window.likeAcceptance = { requests: [], mode: 'normal', release: null };
    window.fetch = async (...args) => {
      const isLike = args[0] === '/like';
      if (isLike) window.likeAcceptance.requests.push(JSON.parse(args[1].body));
      const response = await original(...args);
      if (isLike && window.likeAcceptance.mode === 'lost') {
        window.likeAcceptance.mode = 'normal';
        throw new TypeError('Fixture lost successful response');
      }
      if (isLike && window.likeAcceptance.mode === 'hold') {
        window.likeAcceptance.mode = 'normal';
        await new Promise(resolve => { window.likeAcceptance.release = resolve; });
      }
      return response;
    };
  })()`);
  const initialLikes = await evaluate(`Number(document.querySelector('#like-count').textContent)`);
  await evaluate(`window.likeAcceptance.mode='lost';document.querySelector('#like-btn').click()`);
  await wait(`!document.querySelector('#like-btn').classList.contains('btn-processing') && window.likeAcceptance.requests.length===1`);
  check('lost successful like response rolls visible state back',await evaluate(`document.querySelector('#like-btn').getAttribute('aria-pressed')==='false'`));
  await evaluate(`document.querySelector('#like-btn').click()`);
  await wait(`!document.querySelector('#like-btn').classList.contains('btn-processing') && document.querySelector('#like-btn').getAttribute('aria-pressed')==='true'`);
  check('browser retry repeats desired true rather than toggling',await evaluate(`window.likeAcceptance.requests.length===2 && window.likeAcceptance.requests.every(r=>r.liked===true)`));
  check('lost-response retry does not double count',await evaluate(`Number(document.querySelector('#like-count').textContent)===${initialLikes+1}`));
  await evaluate(`document.querySelector('#like-btn').click()`);
  await wait(`!document.querySelector('#like-btn').classList.contains('btn-processing') && document.querySelector('#like-btn').getAttribute('aria-pressed')==='false'`);
  check('browser explicit unlike restores count',await evaluate(`window.likeAcceptance.requests.at(-1).liked===false && Number(document.querySelector('#like-count').textContent)===${initialLikes}`));
  identity=await evaluate(`document.querySelector('#meme-display').dataset.memeUrl`);
  await evaluate(`window.likeAcceptance.mode='hold';document.querySelector('#like-btn').click()`);
  await wait(`typeof window.likeAcceptance.release==='function'`);
  await evaluate(`document.querySelector('#next-btn').click()`);
  await wait(`document.querySelector('#meme-display').dataset.memeUrl!==${JSON.stringify(identity)} && document.querySelector('#meme-image')?.naturalWidth>0`);
  const otherState=await evaluate(`({liked:document.querySelector('#like-btn').getAttribute('aria-pressed'),count:document.querySelector('#like-count').textContent})`);
  await evaluate(`window.likeAcceptance.release()`);
  await wait(`!document.querySelector('#like-btn').classList.contains('btn-processing')`);
  check('late like response does not repaint another meme',await evaluate(`document.querySelector('#like-btn').getAttribute('aria-pressed')===${JSON.stringify(otherState.liked)} && document.querySelector('#like-count').textContent===${JSON.stringify(otherState.count)}`));
  await evaluate(`document.querySelector('#prev-btn').click()`);
  await wait(`document.querySelector('#meme-display').dataset.memeUrl===${JSON.stringify(identity)}`);
  check('returning to original meme restores confirmed late like',await evaluate(`document.querySelector('#like-btn').getAttribute('aria-pressed')==='true' && Number(document.querySelector('#like-count').textContent)===${initialLikes+1}`));
  await evaluate(`document.querySelector('#like-btn').click()`);
  await wait(`!document.querySelector('#like-btn').classList.contains('btn-processing') && document.querySelector('#like-btn').getAttribute('aria-pressed')==='false'`);
  if (process.env.BROWSER_FIXTURE_ACCOUNT) {
    const email = process.env.BROWSER_FIXTURE_ACCOUNT;
    assert.match(email, /^browser-[a-f0-9]{24}@example\.test$/);
    await send('Page.navigate', {url:`${origin}/signup`});
    await wait(`document.readyState==='complete' && !!document.querySelector('meta[name="csrf-token"]')`);
    const signup = await evaluate(`(async () => {
      const body=new URLSearchParams({email:${JSON.stringify(email)},password:'BrowserFixture!42-pass',password_confirm:'BrowserFixture!42-pass'});
      const r=await fetch('/signup',{method:'POST',body,headers:{'X-CSRF-Token':document.querySelector('meta[name="csrf-token"]').content}});
      return {status:r.status,body:await r.json()};
    })()`);
    check('disposable signup succeeds through browser session',signup.status===200 && signup.body.success===true);
    await send('Page.navigate',{url:`${origin}/random`});
    await wait(`document.querySelector('#meme-image')?.naturalWidth>0 && !!window.mobileSwipe`);
    identity=await evaluate(`document.querySelector('#meme-display').dataset.memeUrl`);
    const baseline=await evaluate(`Number(document.querySelector('#like-count').textContent)`);
    await evaluate(`document.querySelector('#like-btn').click()`);
    await wait(`!document.querySelector('#like-btn').classList.contains('btn-processing') && document.querySelector('#like-btn').getAttribute('aria-pressed')==='true'`);
    check('signed-in button confirms like and count',await evaluate(`Number(document.querySelector('#like-count').textContent)===${baseline+1}`));
    const exactPath=await evaluate(`document.querySelector('#viewer-share-data').dataset.sharePath`);
    assert.match(exactPath,/^\/meme\/[a-f0-9]{64}$/);
    await send('Page.navigate',{url:`${origin}${exactPath}`});
    await wait(`document.querySelector('#meme-image')?.naturalWidth>0 && !!window.mobileSwipe`);
    check('exact-link reload preserves signed-in like and media identity',await evaluate(`document.querySelector('#meme-display').dataset.memeUrl===${JSON.stringify(identity)} && document.querySelector('#like-btn').getAttribute('aria-pressed')==='true' && Number(document.querySelector('#like-count').textContent)===${baseline+1}`));
    await send('Page.navigate',{url:`${origin}/random`});
    await wait(`document.querySelector('#meme-image')?.naturalWidth>0 && !!window.mobileSwipe`);
    // Return via the exact catalog link rather than assuming random reload selects
    // the same media. Query backend history through the visible profile like link.
    await send('Page.navigate',{url:`${origin}/profile`});
    await wait(`document.readyState==='complete' && document.body.innerText.includes(${JSON.stringify(email)})`);
    check('signed-in profile includes liked media after full navigation',await evaluate(`Array.from(document.querySelectorAll('img')).some(img=>new URL(img.src).pathname===new URL(${JSON.stringify(identity)},location.origin).pathname)`));
    const unliked=await evaluate(`(async()=>{const r=await fetch('/like',{method:'POST',headers:{'Content-Type':'application/json','X-CSRF-Token':document.querySelector('meta[name="csrf-token"]').content},body:JSON.stringify({url:${JSON.stringify(identity)},liked:false})});return r.json()})()`);
    check('signed-in unlike restores baseline before cleanup',unliked.success===true && unliked.liked===false && unliked.likes===baseline);
    const logout=await evaluate(`(async()=>{const r=await fetch('/logout',{method:'POST',headers:{'X-CSRF-Token':document.querySelector('meta[name="csrf-token"]').content}});return r.status})()`);
    check('browser logout completes',logout===200);
    await send('Page.navigate',{url:`${origin}/profile`});
    await wait(`location.pathname==='/login' && document.readyState==='complete'`);
    check('profile redirects to login after browser logout',true);
  }
  for (const width of [320, 375, 1280]) {
    await send('Emulation.setDeviceMetricsOverride', {width,height:900,deviceScaleFactor:1,mobile:false});
    await send('Page.navigate',{url:`${origin}/search?q=${encodeURIComponent('browser-no-matches & topic')}`});
    await wait(`!!document.querySelector('.search-empty') && document.readyState==='complete'`);
    check(`${width}px: Search preserves unmatched query`,await evaluate(`document.querySelector('#meme-search').value==='browser-no-matches & topic'`));
    for (const theme of ['light','dark']) {
      await evaluate(`if(document.documentElement.dataset.theme!==${JSON.stringify(theme)})document.querySelector('#darkModeToggle').click()`);
      check(`${width}px ${theme}: empty Search fits viewport`,await evaluate(`document.documentElement.scrollWidth<=innerWidth+1 && document.querySelector('.search-empty').getBoundingClientRect().width<=innerWidth`));
      check(`${width}px ${theme}: empty Search text and links meet 4.5 contrast`,await evaluate(`(() => {
        const luminance=color=>{const channels=color.match(/[0-9.]+/g).slice(0,3).map(Number).map(v=>{v/=255;return v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4});return channels[0]*0.2126+channels[1]*0.7152+channels[2]*0.0722};
        const panel=document.querySelector('.search-empty');const bg=luminance(getComputedStyle(panel).backgroundColor);
        return [panel,...panel.querySelectorAll('a')].every(el=>{const fg=luminance(getComputedStyle(el).color);return (Math.max(fg,bg)+0.05)/(Math.min(fg,bg)+0.05)>=4.5});
      })()`));
      await evaluate(`document.querySelector('.search-recovery a').focus()`);
      await key('Tab');
      check(`${width}px ${theme}: recovery links follow keyboard order with visible focus`,await evaluate(`document.activeElement===document.querySelectorAll('.search-recovery a')[1] && getComputedStyle(document.activeElement).outlineStyle!=='none'`));
    }
    await evaluate(`document.querySelector('.search-recovery a').click()`);
    await wait(`location.pathname==='/search' && location.search==='' && document.readyState==='complete'`);
    check(`${width}px: start new search clears query`,await evaluate(`document.querySelector('#meme-search').value===''`));
  }
  check('no uncaught browser exceptions', exceptions.length === 0);
} finally {
  for (const item of pending.values()) clearTimeout(item.timer);
  ws.close();
}