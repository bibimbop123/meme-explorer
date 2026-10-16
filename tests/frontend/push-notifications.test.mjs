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