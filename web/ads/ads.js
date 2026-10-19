// The browser build's ad bridge: AdSense display units beside the game and
// H5 Games Ads (adBreak) for between-screens and rewarded ads. The game
// reaches it through window.alchemonsAds (lib/services/web_ads_bridge_web.dart).
// Every call settles even when ads are off, blocked or unfilled, so the game
// never waits on an ad that is not coming.
(function () {
  'use strict';

  const cfg = Object.assign(
    { client: '', h5Games: false, slots: {}, interstitialGapSec: 90, every: {}, startAd: true },
    window.ALCHEMONS_ADS || {},
  );
  cfg.slots = Object.assign({ railLeft: '', railRight: '', bottom: '' }, cfg.slots);
  cfg.every = Object.assign({}, cfg.every);
  const params = new URLSearchParams(location.search);
  const test = params.has('adtest');
  const preview = params.has('adpreview');

  // 'off' | 'loading' | 'ready' | 'blocked'
  let script = cfg.client ? 'loading' : 'off';
  window.adsbygoogle = window.adsbygoogle || [];
  const adBreak = (o) => window.adsbygoogle.push(o);

  if (cfg.client) {
    const s = document.createElement('script');
    s.async = true;
    s.crossOrigin = 'anonymous';
    s.src =
      'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=' +
      encodeURIComponent(cfg.client);
    s.setAttribute('data-ad-frequency-hint', cfg.interstitialGapSec + 's');
    if (test) s.setAttribute('data-adbreak-test', 'on');
    s.onload = () => { script = 'ready'; };
    s.onerror = () => { script = 'blocked'; };
    document.head.appendChild(s);
    if (cfg.h5Games) adBreak({ preloadAdBreaks: 'on', sound: 'on' }); // adConfig
  }

  const usable = () => script === 'ready' || script === 'loading';
  // adBreak (start, between-screens, rewarded) only once H5 Games Ads is on.
  const breaks = () => !!cfg.h5Games && usable();
  let lastBreak = 0;
  let showing = false;

  /// One adBreak, wrapped so it always settles. Resolves with whether an ad
  /// actually played. A break that never starts (no fill, not approved yet,
  /// blocked) gives up after [patienceMs].
  function runBreak(options, onStart, onEnd, patienceMs) {
    return new Promise((resolve) => {
      if (!breaks() || showing) return resolve({ played: false });
      let started = false;
      let ended = false;
      let settled = false;
      const end = () => {
        if (!started || ended) return;
        ended = true;
        showing = false;
        try { onEnd && onEnd(); } catch (_) {}
      };
      const finish = (result) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        end();
        resolve(result);
      };
      const timer = setTimeout(() => { if (!started) finish({ played: false }); }, patienceMs);
      adBreak(Object.assign({}, options, {
        beforeAd() {
          started = true;
          showing = true;
          lastBreak = Date.now();
          try { onStart && onStart(); } catch (_) {}
        },
        afterAd: end,
        adBreakDone(info) {
          finish({ played: !!(info && info.breakStatus === 'viewed'), info });
        },
      }));
    });
  }

  /// Resolves with whether an ad played. One too soon after the last does not
  /// try.
  function nextBreak(placement, onStart, onEnd, type) {
    const gap = cfg.interstitialGapSec * 1000;
    if (Date.now() - lastBreak < gap) return Promise.resolve(false);
    return runBreak({ type: type || 'next', name: String(placement) }, onStart, onEnd, 5000)
      .then((r) => r.played);
  }

  function interstitial(placement, onStart, onEnd, type) {
    return nextBreak(placement, onStart, onEnd, type).then(() => null);
  }

  // ── Counted breaks ──────────────────────────────────────────────────────

  const tallyKey = (placement) => 'alchemons.ads.tally.' + placement;

  function readTally(placement) {
    try {
      return Number(localStorage.getItem(tallyKey(placement))) || 0;
    } catch (_) {
      return 0;
    }
  }

  function writeTally(placement, n) {
    try { localStorage.setItem(tallyKey(placement), String(n)); } catch (_) {}
  }

  /// [count] more of [placement] (fusions, extractions). Once cfg.every says
  /// enough have added up, a between-screens ad; the count starts over only
  /// when one actually played, so an ad turned away by the spacing is owed
  /// at the next one.
  function tally(placement, count, onStart, onEnd) {
    const every = Number(cfg.every[placement]) || 0;
    if (every <= 0 || !breaks()) return Promise.resolve(null);
    const n = readTally(placement) + Math.max(1, Math.floor(Number(count) || 1));
    writeTally(placement, n);
    if (n < every) return Promise.resolve(null);
    return nextBreak(placement, onStart, onEnd).then((played) => {
      if (played) writeTally(placement, 0);
      return null;
    });
  }

  function rewarded(placement, onStart, onEnd) {
    let viewed = false;
    return runBreak(
      {
        type: 'reward',
        name: String(placement),
        // The player already chose to watch by pressing the button.
        beforeReward(showAdFn) { showAdFn(); },
        adViewed() { viewed = true; },
        adDismissed() { viewed = false; },
      },
      onStart,
      onEnd,
      6000,
    ).then(() => viewed);
  }

  // ── Display units ───────────────────────────────────────────────────────

  /// Fills [box] with a display unit of [w]×[h] (or a placeholder in preview
  /// mode). Returns false when there is nothing to show there. [onFill] hears
  /// whether Google filled the unit (true) or left it empty (false); a
  /// placeholder counts as filled at once.
  function mountDisplay(box, slotKey, w, h, onFill) {
    box.replaceChildren();
    const slot = cfg.slots[slotKey] || (slotKey === 'railRight' ? cfg.slots.railLeft : '');
    if (preview) {
      const ph = document.createElement('div');
      ph.className = 'ad-placeholder';
      ph.style.width = w + 'px';
      ph.style.height = h + 'px';
      ph.textContent = w + ' × ' + h;
      box.appendChild(ph);
      if (onFill) onFill(true);
      return true;
    }
    if (!cfg.client || !slot || script === 'blocked') return false;
    const ins = document.createElement('ins');
    ins.className = 'adsbygoogle';
    ins.style.display = 'inline-block';
    ins.style.width = w + 'px';
    ins.style.height = h + 'px';
    ins.setAttribute('data-ad-client', cfg.client);
    ins.setAttribute('data-ad-slot', slot);
    if (test) ins.setAttribute('data-adtest', 'on');
    box.appendChild(ins);
    // AdSense marks the unit data-ad-status="filled" or "unfilled" once it
    // has decided.
    if (onFill) {
      new MutationObserver(() => {
        const status = ins.getAttribute('data-ad-status');
        if (status) onFill(status === 'filled');
      }).observe(ins, {attributes: true, attributeFilter: ['data-ad-status']});
    }
    try { window.adsbygoogle.push({}); } catch (_) {}
    return true;
  }

  window.alchemonsAds = {
    // What the game asks before offering an ad of its own (breaks, rewards).
    get configured() { return !!cfg.client && breaks(); },
    get showing() { return showing; },
    get startAd() { return !!cfg.startAd; },
    get hasBottom() { return preview || (!!cfg.client && !!cfg.slots.bottom); },
    get hasRails() { return preview || (!!cfg.client && !!(cfg.slots.railLeft || cfg.slots.railRight)); },
    interstitial,
    tally,
    rewarded,
    mountDisplay,
  };
})();
