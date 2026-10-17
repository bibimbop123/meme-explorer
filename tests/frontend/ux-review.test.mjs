import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFile } from 'node:fs/promises';

const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');

test('initial community is searchable and unseen inventory does not claim freshness', async () => {
  const metadata = await read('views/random/metadata.erb');
  assert.match(metadata, /class="meme-subreddit"/);
  assert.match(metadata, /href="\/search\?q=/);
  assert.match(metadata, /URI.encode_www_form_component/);
  const source = await read('public/js/modules/meme-navigation.js');
  const { MemeNavigation } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
  const nav = Object.create(MemeNavigation.prototype);
  const html = nav.renderInfoHTML({ title: 'Example', subreddit: 'cats', total_unseen: 12 });
  assert.match(html, /12 unseen memes remaining/);
  assert.doesNotMatch(html, /fresh memes remaining/);
});

test('loading announces progress, disables both control groups, and preserves content announcements', async () => {
  const source = await read('public/js/modules/meme-navigation.js');
  const { MemeNavigation } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
  const previous = globalThis.document;
  const status = { textContent: '' };
  const buttons = [{ disabled: false }, { disabled: false }];
  const display = { classList: { add() {}, remove() {} }, setAttribute() {} };
  globalThis.document = {
    getElementById: () => status,
    querySelector: () => display,
    querySelectorAll: selector => {
      assert.equal(selector, '.meme-controls button, .viewer-navigation button');
      return buttons;
    }
  };
  const nav = Object.create(MemeNavigation.prototype);
  nav.updatePreviousAvailability = () => {};
  try {
    nav.showLoadingState();
    assert.equal(status.textContent, 'Loading meme…');
    assert.ok(buttons.every(button => button.disabled));
    nav.hideLoadingState();
    assert.equal(status.textContent, '');
    assert.ok(buttons.every(button => !button.disabled));
    status.textContent = 'Meme: Current title';
    nav.hideLoadingState();
    assert.equal(status.textContent, 'Meme: Current title');
  } finally { globalThis.document = previous; }
});

test('feed navigation precedes tall media and has unique control IDs', async () => {
  const viewer = await read('views/random.erb');
  const controls = await read('views/random/controls.erb');
  assert.ok(viewer.indexOf('class="viewer-navigation"') < viewer.indexOf('id="meme-display"'));
  for (const id of ['prev-btn', 'next-btn']) {
    assert.equal((viewer.match(new RegExp(`id="${id}"`, 'g')) || []).length, 1);
    assert.ok(!controls.includes(`id="${id}"`));
  }
  const css = await read('public/css/viewer-controls.css');
  assert.match(css, /\.viewer-navigation \{[^}]*position: sticky;[^}]*top: 0;/);
  assert.match(controls, /Save to favorites/);
  assert.match(controls, />Download</);
});

test('Search is primary navigation and login does not offer dead recovery', async () => {
  const navigation = await read('views/partials/_simplified_nav.erb');
  assert.ok(navigation.indexOf('href="/search"') < navigation.indexOf('id="hamburgerMenu"'));
  assert.doesNotMatch(await read('views/login.erb'), /href="#"/);
});

test('viewer navigation overrides legacy important mobile styles', async () => {
  const css = await read('public/css/viewer-controls.css');
  assert.match(css, /nav\.main-nav \{[^}]*flex-wrap: wrap !important;[^}]*overflow: visible !important;/);
  assert.match(css, /\.viewer-navigation \.control-btn \{[^}]*font-size: 1rem !important;[^}]*background:[^;]+!important;[^}]*color:[^;]+!important;/);
  assert.match(css, /\.viewer-navigation #next-btn \{[^}]*background: #b91c50 !important;[^}]*color: #fff !important;/);
  assert.match(css, /\.viewer-navigation \.control-btn \{[^}]*overflow-wrap: anywhere;/);
});

test('sticky navigation defines readable dark theme colors and focus indication', async () => {
  const css = await read('public/css/viewer-controls.css');
  assert.match(css, /\[data-theme="dark"\] \.viewer-navigation \{[^}]*--card-bg: #1e1e1e;[^}]*--text-color: #f5f5f5;/);
  assert.match(css, /\[data-theme="dark"\] \.viewer-navigation button:focus-visible \{[^}]*outline-color: #93c5fd;/);
});

test('configured push waits for explicit settings interaction', async () => {
  const source = await read('public/js/push-notifications.js');
  let click;
  let requests = 0;
  const settings = { hidden: true, addEventListener: (event, handler) => { click = handler; } };
  vm.runInNewContext(source, {
    window: { PUSH_NOTIFICATIONS_CONFIG: { enabled: true, vapidPublicKey: 'key' }, PushManager: {} },
    navigator: { serviceWorker: {} },
    Notification: { permission: 'default', requestPermission: async () => { requests++; return 'denied'; } },
    document: { getElementById: () => settings },
    console: { log() {}, error() {} },
    setTimeout: () => assert.fail('No automatic notification prompt')
  });
  assert.equal(settings.hidden, false);
  assert.equal(requests, 0);
  await click();
  assert.equal(requests, 1);
});

test('keyboard help traps Tab, closes from focused controls, and restores focus', async () => {
  const source = await read('public/js/modules/keyboard-navigation.js');
  const listeners = {};
  let restored = false;
  const trigger = { focus: () => { restored = true; } };
  const close = { focus: () => { document.activeElement = close; } };
  const modal = { style: {}, setAttribute() {}, querySelector: () => close, querySelectorAll: () => [close] };
  const document = {
    readyState: 'loading', activeElement: trigger,
    addEventListener: (name, handler) => { listeners[name] = handler; },
    getElementById: () => modal, querySelectorAll: () => [],
    body: { classList: { add() {}, remove() {} } }
  };
  const window = {};
  vm.runInNewContext(source, { window, document, console: { log() {} } });
  const keyboard = window.KeyboardNavigation;
  keyboard.setupEventListeners();
  keyboard.showHelp();
  assert.equal(document.activeElement, close);
  let prevented = 0;
  listeners.keydown({ key: 'Tab', preventDefault: () => { prevented++; } });
  listeners.keydown({ key: 'Tab', shiftKey: true, preventDefault: () => { prevented++; } });
  document.activeElement = trigger;
  listeners.keydown({ key: 'Tab', preventDefault: () => { prevented++; } });
  assert.equal(document.activeElement, close);
  listeners.keydown({ key: 'Escape', preventDefault: () => { prevented++; } });
  assert.equal(prevented, 4);
  assert.equal(keyboard.state.helpModalVisible, false);
  assert.equal(restored, true);
});