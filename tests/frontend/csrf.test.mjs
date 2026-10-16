import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const source = await readFile(new URL('../../public/js/csrf.js', import.meta.url), 'utf8');

function setup() {
  const calls = [];
  let onSubmit;
  const window = {
    location: { href: 'https://memes.example/random', origin: 'https://memes.example' },
    fetch: (...args) => { calls.push(args); return Promise.resolve({ ok: true }); }
  };
  const document = {
    querySelector: () => ({ content: 'session-token' }),
    addEventListener: (_, handler) => { onSubmit = handler; },
    createElement: () => ({})
  };
  vm.runInNewContext(source, { window, document, Request, Headers, URL });
  return { window, calls, submit: event => onSubmit(event) };
}

test('same-origin JSON mutations receive token without changing body or existing headers', async () => {
  const { window, calls } = setup();
  await window.fetch('/like', { method: 'POST', body: '{"url":"meme"}', headers: { 'Content-Type': 'application/json' } });
  assert.equal(calls[0][1].headers.get('X-CSRF-Token'), 'session-token');
  assert.equal(calls[0][1].headers.get('Content-Type'), 'application/json');
  assert.equal(calls[0][1].body, '{"url":"meme"}');
});

test('cross-origin requests never receive the session token', async () => {
  const { window, calls } = setup();
  await window.fetch('https://other.example/collect', { method: 'POST' });
  assert.equal(calls[0][1].headers, undefined);
});

test('GET is unchanged and Request objects retain their identity and method', async () => {
  const { window, calls } = setup();
  await window.fetch('/random.json');
  assert.equal(calls[0][1].headers, undefined);
  const request = new Request('https://memes.example/api/save-meme', { method: 'POST', body: '{}' });
  await window.fetch(request);
  assert.equal(calls[1][0], request);
  assert.equal(calls[1][1].headers.get('X-CSRF-Token'), 'session-token');
});

test('native same-origin form gets a hidden token; external form does not', () => {
  const { submit } = setup();
  let field;
  const form = { action: 'https://memes.example/login', method: 'post', querySelector: () => null, appendChild: value => { field = value; } };
  submit({ target: form });
  assert.equal(field.name, 'authenticity_token');
  assert.equal(field.value, 'session-token');
  field = null;
  form.action = 'https://other.example/login';
  submit({ target: form });
  assert.equal(field, null);
});