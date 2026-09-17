import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import test from 'node:test';
const source = await readFile(new URL('../../web/daymaker_ads.js', import.meta.url), 'utf8');

function harness({ready = true} = {}) {
  const listeners = new Map(), scripts = [], slots = [], displays = [], destroyed = [];
  const observers = [];
  const docListeners = new Map();
  const service = {
    addEventListener(name, fn) {
      const set = listeners.get(name) || new Set(); set.add(fn); listeners.set(name, set);
    },
    removeEventListener(name, fn) { listeners.get(name)?.delete(fn); },
  };
  const queue = [];
  const gpt = {
    apiReady: ready,
    cmd: {push(fn) { if (gpt.apiReady) fn(); else queue.push(fn); }},
    pubads: () => service,
    defineSlot(unit, size, id) {
      const slot = {unit, size, id, addService() { return slot; }};
      slots.push(slot); return slot;
    },
    enableServices() {},
    display(element) { displays.push(element.id); },
    destroySlots(value) { destroyed.push(...value); },
  };
  const document = {
    visibilityState: 'visible', documentElement: {},
    head: {appendChild(script) { scripts.push(script); }},
    querySelector() { return scripts[0]; },
    createElement() { return {}; },
    addEventListener(name, fn) { docListeners.set(name, fn); },
    removeEventListener(name, fn) { if (docListeners.get(name) === fn) docListeners.delete(name); },
  };
  class Observer {
    constructor(fn) { this.fn = fn; observers.push(this); }
    observe() {}
    disconnect() { this.dead = true; }
  }
  const window = {googletag: gpt, innerWidth: 1280, innerHeight: 900};
  vm.runInNewContext(source, {window, document, setTimeout, clearTimeout,
    MutationObserver: Observer, IntersectionObserver: Observer});
  return {
    window, document, scripts, slots, displays, destroyed, observers,
    activate() { gpt.apiReady = true; queue.splice(0).forEach(fn => fn()); },
    emit(name, slot, isEmpty = false) { [...listeners.get(name) || []].forEach(fn => fn({slot, isEmpty})); },
    tick() { observers.filter(o => !o.dead).forEach(o => o.fn()); },
    visibility(state) { document.visibilityState = state; docListeners.get('visibilitychange')?.(); },
  };
}
const element = (connected = true) => ({isConnected: connected,
  getBoundingClientRect: () => ({width: 300, height: 250, top: 100, left: 20, bottom: 350, right: 320})});
const flush = async () => { await Promise.resolve(); await Promise.resolve(); };
const mount = (h, id, allowed, events, div = element()) =>
  h.window.daymakerAds.mount(Object.assign(div, {id}), id, '/123456/daymaker_test', 300, 250, allowed, event => events.push(event));

test('unresolved/revoked consent never injects a tag or requests', async () => {
  const h = harness({ready: false}), events = [];
  mount(h, 'a', () => false, events);
  await flush();
  assert.deepEqual(events, ['eligibility_changed']);
  assert.equal(h.scripts.length, 0);
  assert.equal(h.displays.length, 0);
});

test('actual connected visible DOM is required and request occurs once', async () => {
  const h = harness(), events = [], div = element(false);
  mount(h, 'a', () => true, events, div);
  await flush();
  assert.equal(h.slots.length, 0);
  div.isConnected = true; h.tick(); await flush();
  assert.equal(h.slots.length, 1);
  assert.deepEqual(Array.from(h.slots[0].size), [300, 250]);
  h.tick(); mount(h, 'a', () => true, events, div); await flush();
  assert.deepEqual(h.displays, ['a']);
  assert.deepEqual(events, ['request']);
  h.emit('slotRenderEnded', h.slots[0]);
  assert.deepEqual(events, ['request', 'loaded']);
  h.emit('impressionViewable', h.slots[0]);
  assert.deepEqual(events, ['request', 'loaded', 'viewable']);
  h.window.daymakerAds.destroy('a');
  assert.equal(h.destroyed.length, 1);
});

test('two authorized slots deduplicate GPT script injection', async () => {
  const h = harness({ready: false});
  mount(h, 'a', () => true, []); mount(h, 'b', () => true, []);
  assert.equal(h.scripts.length, 1);
  h.activate(); await flush();
  assert.equal(h.displays.length, 2);
  h.window.daymakerAds.destroy('a'); h.window.daymakerAds.destroy('b');
});

test('no-fill, backgrounding and late script completion safely destroy', async () => {
  const h = harness(), events = [];
  mount(h, 'a', () => true, events); await flush();
  h.emit('slotRenderEnded', h.slots[0], true);
  assert.deepEqual(events, ['request', 'no_fill']);
  assert.equal(h.destroyed.length, 1);
  const late = harness({ready: false}), lateEvents = [];
  mount(late, 'b', () => true, lateEvents);
  late.visibility('hidden'); late.activate(); await flush();
  assert.equal(late.displays.length, 0);
  assert.deepEqual(lateEvents, ['backgrounded']);
});

test('script errors and AdMob configuration are fail closed', async () => {
  const h = harness({ready: false}), events = [];
  mount(h, 'a', () => true, events);
  h.scripts[0].onerror(); await flush();
  assert.deepEqual(events, ['script_error']);
  h.window.daymakerAds.mount(element(), 'b', 'ca-app-pub-123/456', 300, 250,
      () => true, event => events.push(event));
  assert.equal(events.at(-1), 'invalid_configuration');
  assert.equal(h.displays.length, 0);
});


test('latest route or safety gate is rechecked after async tag load and at display', async () => {
  const late = harness({ready: false}), events = [];
  let permitted = true;
  mount(late, 'a', () => permitted, events);
  permitted = false;
  late.activate(); await flush();
  assert.equal(late.displays.length, 0);
  assert.deepEqual(events, ['eligibility_changed']);
  const immediate = harness();
  permitted = true;
  const div = Object.assign(element(), {id:'b'});
  immediate.window.daymakerAds.mount(div, 'b', '/123456/daymaker_fixture', 300, 250,
    () => permitted, event => { if (event === 'request') permitted = false; });
  await flush();
  assert.equal(immediate.displays.length, 0);
  assert.equal(immediate.destroyed.length, 1);
});
