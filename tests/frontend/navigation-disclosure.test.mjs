import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFile } from 'node:fs/promises';

const source = await readFile(new URL('../../public/js/layout-utils.js', import.meta.url), 'utf8');

function setup({ bottom = 140 } = {}) {
  const listeners = {};
  const clicks = {};
  const windowListeners = {};
  let focused = false;
  const toggle = {
    dataset: {}, contains: target => target === toggle,
    closest: () => ({ getBoundingClientRect: () => ({ bottom }) }),
    setAttribute(key, value) { this[key] = value; },
    addEventListener: (name, callback) => { clicks[name] = callback; },
    focus: () => { focused = true; }
  };
  const menu = { style: {}, hidden: true, classList: { toggle() {} }, contains: target => target === menu };
  const context = {
    window: { innerHeight: 812, addEventListener: (name, handler) => { windowListeners[name] = handler; } },
    document: {
      readyState: 'loading',
      getElementById: id => id === 'menuToggle' ? toggle : menu,
      addEventListener: (name, callback) => { listeners[name] = callback; }
    }, module: { exports: {} }
  };
  vm.runInNewContext(source, context);
  context.module.exports.initNavigationDisclosure();
  return { toggle, menu, listeners, clicks, windowListeners, document: context.document, focused: () => focused, initialize: context.module.exports.initNavigationDisclosure };
}

test('navigation disclosure synchronizes visibility and expanded state', () => {
  const app = setup();
  assert.equal(app.menu.hidden, true);
  assert.equal(app.toggle['aria-expanded'], 'false');
  app.clicks.click();
  assert.equal(app.menu.hidden, false);
  assert.equal(app.toggle['aria-expanded'], 'true');
  app.clicks.click();
  assert.equal(app.menu.hidden, true);
});

test('Escape closes disclosure and returns focus to its toggle', () => {
  const app = setup();
  app.clicks.click();
  let prevented = false;
  app.listeners.keydown({ key: 'Escape', preventDefault: () => { prevented = true; } });
  assert.equal(app.menu.hidden, true);
  assert.equal(app.focused(), true);
  assert.equal(prevented, true);
});

test('outside click and focus departure close without trapping normal focus', () => {
  const app = setup();
  app.clicks.click();
  app.listeners.click({ target: app.menu });
  assert.equal(app.menu.hidden, false);
  app.listeners.click({ target: {} });
  assert.equal(app.menu.hidden, true);
  app.clicks.click();
  app.listeners.focusin({ target: {} });
  assert.equal(app.menu.hidden, true);
  assert.equal(app.focused(), false);
});

test('reinitialization does not replace or duplicate toggle handlers', () => {
  const app = setup();
  const handler = app.clicks.click;
  app.initialize();
  assert.equal(app.clicks.click, handler);
});

test('menu follows wrapped header and closes safely when layout changes', () => {
  const app = setup();
  app.clicks.click();
  assert.equal(app.menu.style.top, '148px');
  assert.equal(app.menu.style.maxHeight, '656px');
  app.document.activeElement = app.menu;
  app.windowListeners.resize();
  assert.equal(app.menu.hidden, true);
  assert.equal(app.focused(), true);
  app.clicks.click();
  app.windowListeners.scroll();
  assert.equal(app.menu.hidden, true);
});