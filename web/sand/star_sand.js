/* web/sand/star_sand.js
 *
 * STAR SAND for the browser build: lit grains in the empty rails either side
 * of the centred game column, stirred by the mouse. A classic script (no
 * module, no bundler) that defines window.StarSand.
 *
 *   var sand = StarSand.start(canvas, { layout: {...} });   // layout optional
 *   sand.layout({ width, height, dpr,
 *                 column: {x, y, w, h},          // no sand under it
 *                 obstacles: [{x, y, w, h}] });  // ad boxes: kept clear
 *   sand.pause(); sand.resume(); sand.destroy();
 *
 * All rects are CSS px relative to the viewport. The canvas must be
 * position:fixed; inset:0 (pointer positions are read as clientX/clientY).
 *
 * The simulation and drawing run in a Worker on an OffscreenCanvas
 * (star_sand_worker.js, found next to this file); the page's main thread only
 * forwards pointer events. Without OffscreenCanvas/Worker the same code runs
 * on the main thread with half the grains. It pauses while the page is
 * hidden, and under prefers-reduced-motion it draws a still field.
 */
(function () {
  'use strict';
  if (window.StarSand) return;

  // Captured now: currentScript is only set while this script first runs.
  var script = document.currentScript;
  var WORKER_URL = new URL('star_sand_worker.js', (script && script.src) || location.href).href;

  var KIND = { pointermove: 0, pointerdown: 1, pointerup: 2, pointerleave: 3, pointercancel: 3 };

  // The worker file, loaded as a plain script, for the main-thread fallback.
  var coreWaiters = null;
  function loadCore(cb) {
    if (window.StarSandCore) return cb(true);
    if (coreWaiters) return coreWaiters.push(cb);
    coreWaiters = [cb];
    var s = document.createElement('script');
    s.src = WORKER_URL;
    s.async = true;
    function done(ok) {
      var list = coreWaiters || [];
      coreWaiters = null;
      for (var i = 0; i < list.length; i++) list[i](ok && !!window.StarSandCore);
    }
    s.onload = function () {
      done(true);
    };
    s.onerror = function () {
      done(false);
    };
    (document.head || document.documentElement).appendChild(s);
  }

  function rect(r) {
    return r ? { x: +r.x || 0, y: +r.y || 0, w: +r.w || 0, h: +r.h || 0 } : null;
  }

  function Sand(canvas, opts) {
    this.canvas = canvas;
    this.opts = opts;
    this.mode = 'pending'; // 'worker' | 'main' | 'dead'
    this.worker = null;
    this.runner = null;
    this.layoutMsg = null;
    this.userPaused = false;
    this.hidden = document.visibilityState === 'hidden';
    this.statsWait = {};
    this.statsId = 0;
    this.mq = window.matchMedia ? window.matchMedia('(prefers-reduced-motion: reduce)') : null;
    this.reduced =
      opts.reducedMotion != null ? !!opts.reducedMotion : !!(this.mq && this.mq.matches);

    var self = this;
    this._onPtr = function (e) {
      if (self.reduced || (self.mode !== 'worker' && self.mode !== 'main')) return;
      self._send({ t: 'p', k: KIND[e.type], x: e.clientX, y: e.clientY, ts: e.timeStamp, b: e.buttons });
    };
    this._onVis = function () {
      self.hidden = document.visibilityState === 'hidden';
      self._sendRun();
    };
    this._onMq = function () {
      if (self.opts.reducedMotion != null) return;
      self.reduced = !!self.mq.matches;
      self._send({ t: 'reduced', v: self.reduced });
    };
    var o = { passive: true };
    for (var type in KIND) canvas.addEventListener(type, this._onPtr, o);
    document.addEventListener('visibilitychange', this._onVis);
    if (this.mq) {
      if (this.mq.addEventListener) this.mq.addEventListener('change', this._onMq);
      else if (this.mq.addListener) this.mq.addListener(this._onMq);
    }
    if (opts.layout) this.layout(opts.layout);
    this._boot();
  }

  Sand.prototype._running = function () {
    return !this.userPaused && !this.hidden;
  };

  Sand.prototype._boot = function () {
    var self = this,
      canvas = this.canvas;
    var canWorker =
      !this.opts.mainThread &&
      typeof Worker === 'function' &&
      typeof OffscreenCanvas === 'function' &&
      typeof canvas.transferControlToOffscreen === 'function';
    if (!canWorker) return this._fallback();
    var w;
    try {
      w = new Worker(WORKER_URL);
    } catch (err) {
      return this._fallback();
    }
    this.worker = w;
    // The canvas is handed over only once the worker has said hello: if it
    // never loads, the canvas is still ours for the fallback.
    var fail = function () {
      if (self.mode !== 'pending') return;
      clearTimeout(timer);
      w.terminate();
      self.worker = null;
      self._fallback();
    };
    var timer = setTimeout(fail, 6000);
    w.onerror = fail;
    w.onmessage = function (e) {
      var m = e.data;
      if (!m) return;
      if (m.t === 'hello' && self.mode === 'pending') {
        clearTimeout(timer);
        var off;
        try {
          off = canvas.transferControlToOffscreen();
        } catch (err) {
          w.terminate();
          self.worker = null;
          return self._fallback();
        }
        self.mode = 'worker';
        w.onerror = null;
        w.postMessage(
          { t: 'init', canvas: off, reduced: self.reduced, run: self._running(), L: self.layoutMsg },
          [off]
        );
      } else if (m.t === 'stats') {
        var cb = self.statsWait[m.id];
        delete self.statsWait[m.id];
        if (cb) cb(m.s);
      }
    };
  };

  Sand.prototype._fallback = function () {
    var self = this;
    this.mode = 'loading';
    loadCore(function (ok) {
      if (self.mode !== 'loading') return;
      if (!ok) {
        self.mode = 'dead';
        return;
      }
      self.runner = new window.StarSandCore.Runner(self.canvas, {
        half: true,
        reduced: self.reduced,
        run: self._running(),
      });
      self.mode = 'main';
      if (self.layoutMsg) self.runner.handle({ t: 'layout', L: self.layoutMsg });
    });
  };

  Sand.prototype._send = function (m) {
    if (this.mode === 'worker') this.worker.postMessage(m);
    else if (this.mode === 'main') this.runner.handle(m);
    // Otherwise still starting: the layout and run state go with the start.
  };

  Sand.prototype._sendRun = function () {
    this._send({ t: 'run', on: this._running() });
  };

  /** The viewport, the column and the obstacles, in CSS px. */
  Sand.prototype.layout = function (L) {
    if (!L) return;
    var obs = [];
    var list = L.obstacles || [];
    for (var i = 0; i < list.length; i++) {
      var r = rect(list[i]);
      if (r && r.w > 0 && r.h > 0) obs.push(r);
    }
    this.layoutMsg = {
      width: +L.width || window.innerWidth,
      height: +L.height || window.innerHeight,
      dpr: +L.dpr || window.devicePixelRatio || 1,
      column: rect(L.column),
      obstacles: obs,
    };
    this._send({ t: 'layout', L: this.layoutMsg });
  };

  Sand.prototype.pause = function () {
    this.userPaused = true;
    this._sendRun();
  };

  Sand.prototype.resume = function () {
    this.userPaused = false;
    this._sendRun();
  };

  Sand.prototype.destroy = function () {
    if (this.mode === 'dead') return;
    for (var type in KIND) this.canvas.removeEventListener(type, this._onPtr);
    document.removeEventListener('visibilitychange', this._onVis);
    if (this.mq) {
      if (this.mq.removeEventListener) this.mq.removeEventListener('change', this._onMq);
      else if (this.mq.removeListener) this.mq.removeListener(this._onMq);
    }
    if (this.worker) this.worker.terminate();
    if (this.runner) this.runner.handle({ t: 'destroy' });
    this.worker = null;
    this.runner = null;
    this.mode = 'dead';
  };

  /** Debug: frame timings and counts (a Promise). Pass true to reset them. */
  Sand.prototype.stats = function (reset) {
    var self = this;
    return new Promise(function (resolve) {
      if (self.mode === 'worker') {
        var id = ++self.statsId;
        self.statsWait[id] = resolve;
        self.worker.postMessage({ t: 'stats', id: id, reset: !!reset });
      } else if (self.mode === 'main') {
        if (reset) self.runner.resetStats();
        var s = self.runner.getStats();
        s.thread = 'main';
        resolve(s);
      } else resolve({ mode: self.mode });
    }).then(function (s) {
      if (s && !s.thread) s.thread = self.mode === 'worker' ? 'worker' : self.mode;
      return s;
    });
  };

  /**
   * Debug: times scripted frames where the sand runs (a Promise).
   * o = { kind: 'stir' | 'hold' | 'idle', frames: 240, freeze: false }.
   */
  Sand.prototype.bench = function (o) {
    var self = this;
    return new Promise(function (resolve) {
      if (self.mode === 'worker') {
        var id = ++self.statsId;
        self.statsWait[id] = resolve;
        self.worker.postMessage({ t: 'bench', id: id, o: o || {} });
      } else if (self.mode === 'main') resolve(self.runner.bench(o || {}));
      else resolve(null);
    });
  };

  window.StarSand = {
    start: function (canvas, opts) {
      return new Sand(canvas, opts || {});
    },
  };
})();
