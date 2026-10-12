// Lays out the page around the browser build and holds the game at the
// start gate until the player presses PLAY. That press is what lets the
// browser play the game's music, so the game is not started before it.
(function () {
  'use strict';

  const MIN_RAIL = 200;   // px either side before the column is worth it
  const AD_GAP = 22;      // keeps the sand (and stray clicks) off an ad
  const LABEL = 30;       // the "Advertisement" label above a unit, and its gap
  const MIN_WIDE_H = 480; // shorter is a phone held sideways: no column
  const TURNED_ASPECT = 2.16;    // the column on its side: a phone's landscape
  const MIN_TURNED_ASPECT = 1.8; // narrower than this, the rail ads give way
  const TURNED_SIDE = 24;        // least margin either side of it

  // Android's browser can turn the real screen (in fullscreen), so the game
  // there fills the screen and turns it as the app does. Elsewhere the
  // column turns instead. See Turning, below.
  const ANDROID = /Android/i.test(navigator.userAgent);
  // The game has asked for landscape.
  let turnedWide = false;

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
    // Never on Android, whose screen turns with the game (see Turning), nor
    // on a phone held sideways: too short for rails.
    const wide = !ANDROID && W > H && H >= MIN_WIDE_H && W >= colW + 2 * MIN_RAIL;
    body.classList.toggle('wide', wide);

    const obstacles = [];
    let column;

    if (wide) {
      const tallX = Math.round((W - colW) / 2);
      // The rail unit is picked for the column standing up, and kept while
      // it lies on its side: a turn never reloads an ad.
      const unit = ads && ads.hasRails ? railUnit(tallX, H) : null;
      let box = { x: tallX, y: 0, w: colW, h: H };
      let railsFit = true;
      if (turnedWide) {
        // The same phone on its side, as wide as a phone held sideways, and
        // narrower if that is what keeps the rail ads beside it.
        const h = colW;
        const ad = unit && (rails.railLeft.filled || rails.railRight.filled);
        let w = Math.min(Math.round(h * TURNED_ASPECT), W - 2 * (ad ? unit[0] + 2 * AD_GAP : TURNED_SIDE));
        if (w < h * MIN_TURNED_ASPECT) {
          w = Math.min(Math.round(h * TURNED_ASPECT), W - 2 * TURNED_SIDE);
          railsFit = false;
        }
        box = { x: Math.round((W - w) / 2), y: Math.round((H - h) / 2), w, h };
      }
      root.style.setProperty('--col-x', box.x + 'px');
      root.style.setProperty('--col-y', box.y + 'px');
      root.style.setProperty('--col-w', box.w + 'px');
      root.style.setProperty('--col-b', H - box.y - box.h + 'px');
      root.style.setProperty('--bottom', '0px');
      // The sand lies round the column standing up; laid on its side, the
      // column is a box the grains glide aside from, and back when it stands.
      column = { x: tallX, y: 0, w: colW, h: H };
      if (turnedWide) obstacles.push(box);
      bottom.el.classList.remove('on');

      const railW = box.x;
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
        rail.el.classList.toggle('tucked', !railsFit);
        if (!on || !rail.filled || !railsFit) continue;
        const left = side === 0 ? Math.round((railW - w) / 2) : Math.round(box.x + box.w + (railW - w) / 2);
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
      root.style.setProperty('--col-y', '0px');
      root.style.setProperty('--col-w', W + 'px');
      root.style.setProperty('--col-b', reserve + 'px');
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

  // ── Turning ────────────────────────────────────────────────────────────

  // The game turns the screen as the app does, through
  // SystemChrome.setPreferredOrientations, which Flutter's web engine hands
  // to screen.orientation.lock (the first orientation asked for). A desktop
  // browser has no screen to turn and refuses; there the column lies on its
  // side instead, on the black frame the game turns on. Android's browser
  // turns the real screen, but only in fullscreen: PLAY asks for it.
  const orientation = screen.orientation;
  let nativeLock = null;
  let lockType = 'portrait-primary';
  let broaden = 0;

  function goFullscreen() {
    const el = document.documentElement;
    if (document.fullscreenElement || !el.requestFullscreen) return;
    el.requestFullscreen({ navigationUI: 'hide' }).catch(() => {});
  }

  // Locks the screen the way the game last asked (fullscreen only).
  function applyLock() {
    clearTimeout(broaden);
    if (!nativeLock || !document.fullscreenElement) return;
    const type = lockType;
    nativeLock(type).then(() => {
      // Turned exactly as asked, so the portal's counter-turn holds; then
      // either way round, as the app allows once it has arrived.
      if (!type.startsWith('landscape')) return;
      broaden = setTimeout(() => {
        if (lockType === type && document.fullscreenElement) {
          nativeLock('landscape').catch(() => {});
        }
      }, 2000);
    }, () => {});
  }

  if (orientation && typeof orientation.lock === 'function') {
    nativeLock = orientation.lock.bind(orientation);
    const nativeUnlock = orientation.unlock ? orientation.unlock.bind(orientation) : () => {};
    orientation.lock = function (type) {
      type = String(type);
      const wide = type.startsWith('landscape');
      if (!ANDROID) {
        if (wide !== turnedWide) {
          turnedWide = wide;
          cancelAnimationFrame(pending);
          layout();
        }
        return Promise.resolve();
      }
      turnedWide = wide;
      lockType = type;
      if (document.fullscreenElement) {
        applyLock();
      } else if (wide && navigator.userActivation && navigator.userActivation.isActive) {
        // Left fullscreen since PLAY: the tap that led here may bring it
        // back (and fullscreenchange locks).
        goFullscreen();
      }
      return Promise.resolve();
    };
    orientation.unlock = function () {
      // Desktop: the column keeps its shape.
      if (ANDROID) {
        clearTimeout(broaden);
        try { nativeUnlock(); } catch (_) {}
      }
    };
  }

  if (ANDROID) {
    document.addEventListener('fullscreenchange', applyLock);
    // A landscape scene showing upright (fullscreen was left): the next tap
    // goes back to fullscreen, and the screen turns.
    window.addEventListener('pointerup', () => {
      if (turnedWide && !document.fullscreenElement && window.innerHeight > window.innerWidth) {
        goFullscreen();
      }
    }, true);
  }

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
    // Before anything is awaited: fullscreen needs this click.
    if (ANDROID) goFullscreen();
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
