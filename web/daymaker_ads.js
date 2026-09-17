/* Manual fixed GAM display slots only. Loaded locally; no Google script, ad
 * request, cookies, or consent claim is made until a verified CMP permits it.
 * https://developers.google.com/publisher-tag/reference
 * https://developers.google.com/publisher-tag/samples/ad-event-listeners
 */
(() => {
  'use strict';
  if (window.daymakerAds) return;
  const TAG = 'https://securepubads.g.doubleclick.net/tag/js/gpt.js';
  const owned = new Map();
  let tagPromise;

  function tag() {
    if (tagPromise) return tagPromise;
    tagPromise = new Promise((resolve, reject) => {
      window.googletag = window.googletag || {cmd: []};
      const timeout = setTimeout(() => reject(new Error('script_timeout')), 15000);
      window.googletag.cmd.push(() => {
        clearTimeout(timeout);
        resolve(window.googletag);
      });
      if (window.googletag.apiReady) return;
      let script = document.querySelector(`script[src="${TAG}"]`);
      if (script) return;
      script = document.createElement('script');
      script.src = TAG;
      script.async = true;
      script.crossOrigin = 'anonymous';
      script.onerror = () => {
        clearTimeout(timeout);
        reject(new Error('script_blocked'));
      };
      document.head.appendChild(script);
    });
    return tagPromise;
  }

  function destroy(id) {
    const state = owned.get(id);
    if (!state) return;
    owned.delete(id);
    state.disposed = true;
    clearTimeout(state.timeout);
    state.intersection?.disconnect();
    state.mutation?.disconnect();
    document.removeEventListener('visibilitychange', state.visibility);
    if (state.gpt && state.slot) {
      for (const [name, listener] of state.listeners) {
        state.gpt.pubads().removeEventListener(name, listener);
      }
      state.gpt.destroySlots([state.slot]);
    }
    state.slot = null;
    state.element = null;
  }

  function fail(state, reason) {
    if (state.disposed) return;
    const callback = state.event;
    destroy(state.id);
    callback(reason);
  }

  function visible(state) {
    const element = state.element;
    if (!element?.isConnected || document.visibilityState !== 'visible') return false;
    const rect = element.getBoundingClientRect();
    return rect.width >= state.width && rect.height >= state.height &&
      rect.bottom > 0 && rect.right > 0 && rect.top < window.innerHeight &&
      rect.left < window.innerWidth;
  }

  async function attempt(state) {
    if (state.disposed || state.started) return;
    if (!state.allowed()) return fail(state, 'eligibility_changed');
    if (!visible(state)) return;
    state.started = true;
    try {
      const gpt = await tag();
      if (state.disposed) return;
      if (!state.allowed()) return fail(state, 'eligibility_changed');
      if (!visible(state)) return fail(state, 'hidden_before_request');
      state.gpt = gpt;
      state.slot = gpt.defineSlot(state.unit, [state.width, state.height], state.id);
      if (!state.slot) return fail(state, 'invalid_slot');
      state.slot.addService(gpt.pubads());
      const rendered = event => {
        if (state.disposed || event.slot !== state.slot) return;
        clearTimeout(state.timeout);
        if (event.isEmpty) return fail(state, 'no_fill');
        // A match/render is not an impression and never generates revenue here.
        state.event('loaded');
      };
      const viewable = event => {
        if (!state.disposed && event.slot === state.slot) state.event('viewable');
      };
      state.listeners = [['slotRenderEnded', rendered], ['impressionViewable', viewable]];
      for (const [name, listener] of state.listeners) {
        gpt.pubads().addEventListener(name, listener);
      }
      gpt.enableServices();
      state.timeout = setTimeout(() => fail(state, 'inventory_timeout'), 15000);
      state.event('request');
      // display is the one and only request. No refresh, hidden frames, out-of-
      // page formats, artificial clicks, creative mutation, or retry timer.
      if (!state.allowed() || !visible(state)) return fail(state, 'eligibility_changed');
      gpt.display(state.element);
    } catch (_) {
      fail(state, 'script_error');
    }
  }

  function mount(element, id, unit, width, height, allowed, event) {
    if (owned.has(id)) return;
    if (!/^\/\d+\/[A-Za-z0-9_/-]+$/.test(unit) ||
        ![[320,50],[728,90],[300,250]].some(size => size[0] === width && size[1] === height)) {
      event('invalid_configuration');
      return;
    }
    const state = {element, id, unit, width, height, allowed, event,
      started: false, disposed: false, listeners: [], slot: null, gpt: null};
    owned.set(id, state);
    state.visibility = () => {
      if (document.visibilityState !== 'visible' && state.started) fail(state, 'backgrounded');
      else attempt(state);
    };
    document.addEventListener('visibilitychange', state.visibility);
    state.intersection = new IntersectionObserver(() => {
      if (state.started && !visible(state)) fail(state, 'hidden');
      else attempt(state);
    });
    state.intersection.observe(element);
    // Flutter creates platform elements before attaching them to its shadow DOM.
    state.mutation = new MutationObserver(() => {
      if (state.disposed) return;
      if (state.element.isConnected) {
        state.mutation.disconnect();
        attempt(state);
      }
    });
    state.mutation.observe(document.documentElement, {subtree: true, childList: true});
    attempt(state);
  }

  window.daymakerAds = Object.freeze({mount, destroy});
})();
