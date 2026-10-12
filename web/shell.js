// Lays out the page around the browser build and holds the game at the
// start gate until the player presses PLAY. That press is what lets the
// browser play the game's music, so the game is not started before it.
(function () {
  'use strict';

  const MIN_RAIL = 200;   // px either side before the column is worth it
  const AD_GAP = 22;      // keeps the sand (and stray clicks) off an ad
  const LABEL = 30;       // the "Advertisement" label above a unit, and its gap

  const body = document.body;
  const root = document.documentElement;
  const sandCanvas = document.getElementById('sand');
  const play = document.getElementById('play');
  const gate = document.getElementById('gate');
  const ads = window.alchemonsAds;

  // `filled`: Google has put an ad in the unit. Until then (and if it never
  // does) the slot is invisible and the sand shows through.
  const rails = {
    railLeft: { el: document.getElementById('ad-left'), size: '', filled: false },
    railRight: { el: document.getElementById('ad-right'), size: '', filled: false },
  };
  const bottom = { el: document.getElementById('bottom-ad'), size: '', filled: false };
  const onFill = (slot) => (filled) => {
    if (slot.filled === filled) return;
    slot.filled = filled;
    cancelAnimationFrame(pending);
    pending = requestAnimationFrame(layout);
  };

  let pending = 0;
  let sand = null;
  try {
    if (window.StarSand) sand = window.StarSand.start(sandCanvas, {});
  } catch (e) {
    console.warn('Star sand unavailable', e);
  }

  /// The largest standard unit that fits a rail [w]×[h], or null.
  function railUnit(w, h) {
    if (w >= 300 + 2 * AD_GAP && h >= 600 + 140) return [300, 600];
    if (w >= 160 + 2 * AD_GAP && h >= 600 + 120) return [160, 600];
    if (w >= 300 + 2 * AD_GAP && h >= 250 + 100) return [300, 250];
    return null;
  }

  function layout() {
    const W = window.innerWidth;
    const H = window.innerHeight;
    // A phone held upright: ~0.47 of the height, within reason.
    const colW = Math.round(Math.min(520, Math.max(360, H * 0.47)));
    const wide = W > H && W >= colW + 2 * MIN_RAIL;
    body.classList.toggle('wide', wide);

    const obstacles = [];
    let column;

    if (wide) {
      const x = Math.round((W - colW) / 2);
      root.style.setProperty('--col-x', x + 'px');
      root.style.setProperty('--col-w', colW + 'px');
      root.style.setProperty('--bottom', '0px');
      column = { x, y: 0, w: colW, h: H };
      bottom.el.classList.remove('on');

      const railW = x;
      const unit = ads && ads.hasRails ? railUnit(railW, H) : null;
      for (const [key, side] of [['railLeft', 0], ['railRight', 1]]) {
        const rail = rails[key];
        if (!unit) {
          rail.el.classList.remove('on');
          continue;
        }
        const [w, h] = unit;
        const size = w + 'x' + h;
        if (rail.size !== size) {
          // Only when the unit itself changes: ads are not refreshed.
          rail.filled = false;
          rail.size = ads.mountDisplay(rail.el.querySelector('.ad-box'), key, w, h, onFill(rail))
            ? size : 'none';
        }
        const on = rail.size !== 'none';
        // Laid out (AdSense won't fill a unit with no size) but unseen until
        // filled; the sand only steers round an ad that is really there.
        rail.el.classList.toggle('on', on);
        rail.el.classList.toggle('filled', on && rail.filled);
        if (!on || !rail.filled) continue;
        const left = side === 0 ? Math.round((railW - w) / 2) : Math.round(x + colW + (railW - w) / 2);
        const top = Math.round((H - h) / 2) - 8;
        rail.el.style.left = left + 'px';
        rail.el.style.top = top - LABEL + 'px';
        obstacles.push({ x: left, y: top - LABEL, w, h: h + LABEL });
      }
    } else {
      for (const rail of Object.values(rails)) rail.el.classList.remove('on');
      let reserve = 0;
      if (ads && ads.hasBottom && W >= 320 && H >= 560) {
        if (bottom.size !== '320x50') {
          bottom.filled = false;
          bottom.size = ads.mountDisplay(bottom.el, 'bottom', 320, 50, onFill(bottom))
            ? '320x50' : 'none';
        }
        // The game gives up the strip only once there is an ad to put in it.
        if (bottom.size !== 'none' && bottom.filled) reserve = 60;
      }
      bottom.el.classList.toggle('on', bottom.size !== 'none' && bottom.size !== '');
      bottom.el.classList.toggle('filled', reserve > 0);
      root.style.setProperty('--col-x', '0px');
      root.style.setProperty('--col-w', W + 'px');
      root.style.setProperty('--bottom', reserve + 'px');
      column = { x: 0, y: 0, w: W, h: H };
    }

    if (sand) {
      sand.layout({
        width: W,
        height: H,
        dpr: Math.min(window.devicePixelRatio || 1, 2),
        column,
        obstacles: obstacles.map((o) => ({ x: o.x, y: o.y, w: o.w, h: o.h })),
      });
      // Nothing to see behind a full-screen game.
      wide ? sand.resume() : sand.pause();
    }
  }

  window.addEventListener('resize', () => {
    cancelAnimationFrame(pending);
    pending = requestAnimationFrame(layout);
  });
  layout();

  // ── Store links ────────────────────────────────────────────────────────

  // From the site's js/stores.js. A store without a link yet stays as plain
  // text marked "soon", so the start screen still says the apps exist.
  (function storeLinks() {
    const stores = window.ALCHEMONS_STORES || {};
    let live = 0;
    for (const a of document.querySelectorAll('.gate-store')) {
      const url = stores[a.dataset.store];
      if (url) {
        a.href = url;
        live++;
      } else {
        a.removeAttribute('href');
        a.classList.add('soon');
      }
    }
    document.getElementById('gate-apps-note').textContent = live
      ? 'Same account on both: back up here, restore in the app.'
      : 'Coming soon. Your account will carry this game over.';
  })();

  // ── Start gate ─────────────────────────────────────────────────────────

  let engineReady = false;
  let pressed = false;
  let release;
  const released = new Promise((r) => { release = r; });

  function refreshButton() {
    play.disabled = !engineReady || pressed;
    play.textContent = pressed ? 'Starting' : engineReady ? 'Play' : 'Loading';
  }

  play.addEventListener('click', async () => {
    if (!engineReady || pressed) return;
    pressed = true;
    refreshButton();
    // Ask the browser to keep the save (IndexedDB/OPFS) rather than evict it
    // under storage pressure.
    try { navigator.storage && navigator.storage.persist && navigator.storage.persist(); } catch (_) {}
    if (ads && ads.configured && ads.startAd) {
      await ads.interstitial('play', null, null, 'start');
    }
    release();
  });

  window.alchemonsShell = {
    /// The engine is loaded; PLAY can start the game.
    engineReady() {
      engineReady = true;
      refreshButton();
    },
    /// Resolves once the player has pressed PLAY (and any start ad is over).
    waitForPlay: () => released,
    /// The game is running: lift the gate.
    started() {
      gate.classList.add('gone');
      setTimeout(() => gate.remove(), 1200);
    },
    failed(error) {
      play.disabled = true;
      play.textContent = 'Could not load';
      console.error(error);
    },
  };
  refreshButton();
})();
