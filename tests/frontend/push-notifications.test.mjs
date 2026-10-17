import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFile } from 'node:fs/promises';

const source = await readFile(new URL('../../public/js/push-notifications.js', import.meta.url), 'utf8');
test('unconfigured push never prompts or registers a service worker', () => {
  for (const vapidPublicKey of [undefined, '', '  ']) {
    vm.runInNewContext(source, {
      window: { PUSH_NOTIFICATIONS_CONFIG: { enabled: true, vapidPublicKey } },
      navigator: { serviceWorker: { register: () => assert.fail('unexpected registration') } },
      setTimeout: () => assert.fail('unexpected prompt')
    });
  }
});

for (const success of [false, true]) {
  test(`push confirmation follows persisted success=${success}`, async () => {
    const messages = [];
    const window = { PUSH_NOTIFICATIONS_CONFIG: { enabled: true, vapidPublicKey: 'test-key' }, PushManager: {} };
    const document = {
      getElementById: () => null, querySelector: () => ({ content: 'csrf' }),
      createElement: () => ({ style: {}, remove() {} }),
      body: { appendChild: element => messages.push(element.textContent) }
    };
    vm.runInNewContext(source, {
      window, document, console: { log() {}, error() {} }, setTimeout() {},
      Notification: { permission: 'default', requestPermission: async () => 'granted' },
      navigator: { serviceWorker: { ready: Promise.resolve(), register: async () => ({ pushManager: { subscribe: async () => ({ endpoint: 'test' }) } }) } },
      fetch: async () => ({ ok: true, json: async () => ({ success }) })
    });
    await window.enablePushNotifications();
    assert.equal(messages.length, success ? 1 : 0);
  });
}

for (const permission of ['denied', 'default']) {
  test(`notification settings explain ${permission} without subscribing`, async () => {
    const status = { hidden: true, textContent: '' };
    const settings = { hidden: true, disabled: false, addEventListener() {} };
    let requests = 0;
    let resolve;
    const response = new Promise(done => { resolve = done; });
    const window = { PUSH_NOTIFICATIONS_CONFIG: { enabled: true, vapidPublicKey: 'test-key' }, PushManager: {} };
    vm.runInNewContext(source, {
      window,
      document: { getElementById: id => id === 'notification-settings' ? settings : status },
      navigator: { serviceWorker: { register: () => assert.fail('Must not subscribe') } },
      Notification: { permission: 'default', requestPermission: () => { requests++; return response; } },
      console: { log() {}, error() {} }
    });
    const first = window.enablePushNotifications();
    assert.equal(settings.disabled, true);
    await window.enablePushNotifications();
    assert.equal(requests, 1);
    resolve(permission);
    await first;
    assert.equal(settings.disabled, false);
    assert.equal(status.hidden, false);
    assert.match(status.textContent, permission === 'denied' ? /browser’s site settings/ : /not enabled/);
  });
}

test('failed subscription persistence stays retryable and only confirmed success hides settings', async () => {
  const status = { hidden: true, textContent: '' };
  const settings = { hidden: true, disabled: false, addEventListener() {} };
  let succeeds = false;
  const messages = [];
  const window = { PUSH_NOTIFICATIONS_CONFIG: { enabled: true, vapidPublicKey: 'test-key' }, PushManager: {} };
  vm.runInNewContext(source, {
    window,
    document: {
      getElementById: id => id === 'notification-settings' ? settings : id === 'notification-status' ? status : null,
      querySelector: () => ({ content: 'csrf' }),
      createElement: () => ({ style: {}, remove() {} }),
      body: { appendChild: element => messages.push(element.textContent) }
    },
    navigator: { serviceWorker: {
      ready: Promise.resolve(),
      register: async () => ({ pushManager: { subscribe: async () => ({ endpoint: 'test' }) } })
    } },
    Notification: { permission: 'default', requestPermission: async () => 'granted' },
    fetch: async () => ({ ok: succeeds, json: async () => ({ success: succeeds }) }),
    console: { log() {}, error() {} }, setTimeout() {}
  });
  await window.enablePushNotifications();
  assert.match(status.textContent, /could not be saved/);
  assert.equal(settings.hidden, false);
  assert.equal(settings.disabled, false);
  assert.equal(messages.length, 0);
  succeeds = true;
  await window.enablePushNotifications();
  assert.equal(status.textContent, 'Notification subscription saved.');
  assert.equal(settings.hidden, true);
  assert.equal(messages.length, 1);
});

test('already-granted permission exposes retry when startup registration fails', async () => {
  const settings = { hidden: true, addEventListener() {} };
  const status = { hidden: true, textContent: '' };
  vm.runInNewContext(source, {
    window: { PUSH_NOTIFICATIONS_CONFIG: { enabled: true, vapidPublicKey: 'key' }, PushManager: {} },
    document: { getElementById: id => id === 'notification-settings' ? settings : status },
    Notification: { permission: 'granted' },
    navigator: { serviceWorker: { register: async () => { throw new Error('unavailable'); } } },
    console: { log() {}, error() {} }
  });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(settings.hidden, false);
  assert.equal(status.hidden, false);
  assert.match(status.textContent, /Enable notifications to retry/);
});