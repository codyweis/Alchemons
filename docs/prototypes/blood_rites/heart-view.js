  // ═══ THE HEART — the fifth rite (the author's design, 2026-10-06) ════════
  // Blood is taken and bound in the niche across the room; the four it freed
  // pour in and stand on the stage. Tap one, then tap where it should go. Two
  // standing on an altar's stones fuse; what they make shoots its power down
  // that altar's lane, and whatever it breaks lets go of the element it was
  // holding, which joins you. The split stage takes a fused creature apart.
  // Light + Dark make Blood, and that frees the Blood that was taken.
  const HR = window.HeartEngine;
  const FAMS = ['horn', 'kin', 'let', 'mane', 'mask', 'pip', 'wing'];
  const ELC = Object.assign({}, EL, FUSE, {
    Crystal: '#b7a2f2', Poison: '#86c94a', Spirit: '#e6e0ff', Light: '#fff0b0', Dark: '#7a5aa8',
    Plant: '#5fb04a', Blood: BLOOD,
  });
  const heart = {
    R: HR.parseRoom(ROOMS.heart), S: null, sel: null, walk: null, fx: [], pos: new Map(), names: new Map(),
    hide: new Set(), oldCells: new Map(), capture: -1, freedT: -1,
  };
  let heartDone = (() => { try { return localStorage.getItem('blood-rites-heart') === '1'; } catch (e) { return false; } })();
  function heartName(c) {
    if (!heart.names.has(c)) heart.names.set(c, c.el + (c.parts || c.freedFrom ? FAMS[Math.floor(Math.random() * FAMS.length)] : 'kin'));
    return heart.names.get(c);
  }
  function resetHeart(withCapture) {
    heart.S = HR.start(heart.R);
    heart.sel = null; heart.walk = null; heart.fx = []; heart.pos = new Map(); heart.hide = new Set(); heart.oldCells = new Map();
    heart.freedT = -1; heart.reformed = false; heart.bloodFlow = null;
    for (const c of heart.S.cs) heart.pos.set(c, [c.at[0], c.at[1]]);
    heart.capture = withCapture && !reduce ? 0 : -1;
  }
  resetHeart(true);

  const hc = (x) => (x + .5) * U;
  function heartCell(e) {
    const r = cv.getBoundingClientRect();
    return [Math.floor((e.clientX - r.left) / U), Math.floor((e.clientY - r.top) / U)];
  }
  function creature(cx, cy, el, r, a) {
    ctx.save(); ctx.globalAlpha = a == null ? 1 : a;
    softGlow(cx, cy, r * 2.2, ELC[el] || GOLD, .22);
    bulb(cx, cy, r, ELC[el] || GOLD, .04 * Math.sin(time * 4 + cx));
    ctx.fillStyle = 'rgba(10,6,7,.75)';
    ctx.font = `600 ${Math.max(9, r * .7)}px ${getComputedStyle(document.body).fontFamily}`;
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(el.slice(0, 2), cx, cy + 1);
    ctx.restore();
  }

  // ── drawing ──
  function obstacle(ch, x, y, a, held) {
    const cx = hc(x), cy = hc(y), x0 = x * U, y0 = y * U;
    ctx.save(); ctx.globalAlpha = a;
    // what it holds, seen through it
    if (held && ch !== '_') { softGlow(cx, cy, U * .5, ELC[held], .35); }
    if (ch === 'I') {
      ice(x, y);
      if (held) { ctx.globalAlpha = a * .55; bulb(cx, cy + U * .04, U * .2, ELC[held], 0); }
    } else if (ch === 'T') {
      ctx.fillStyle = '#2a0c12'; ctx.beginPath(); ctx.ellipse(cx, cy + U * .08, U * .44, U * .38, 0, 0, Math.PI * 2); ctx.fill();
      if (held) { bulb(cx, cy + U * .05, U * .16, ELC[held], 0); }
      for (let k = 0; k < 9; k++) {
        const ang = k * 2.4 + .3, r1 = U * .18, r2 = U * (.42 + .06 * hash(x, y, k));
        ctx.fillStyle = k % 2 ? '#8a1626' : '#c8283c';
        ctx.beginPath(); ctx.moveTo(cx + Math.cos(ang - .25) * r1, cy + Math.sin(ang - .25) * r1);
        ctx.lineTo(cx + Math.cos(ang) * r2, cy + Math.sin(ang) * r2); ctx.lineTo(cx + Math.cos(ang + .25) * r1, cy + Math.sin(ang + .25) * r1); ctx.fill();
      }
    } else if (ch === 'K') {
      if (held) { ctx.globalAlpha = a * .7; bulb(cx, cy + U * .1, U * .2, ELC[held], 0); ctx.globalAlpha = a; }
      for (let k = 0; k < 4; k++) {
        const bx = x0 + U * (.12 + k * .2), h = U * (.6 + .3 * hash(x, y, k));
        const g = ctx.createLinearGradient(bx, y0 + U - h, bx + U * .2, y0 + U);
        g.addColorStop(0, 'rgba(239,230,255,.85)'); g.addColorStop(1, 'rgba(106,79,184,.85)');
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.moveTo(bx, y0 + U * .95); ctx.lineTo(bx + U * .11, y0 + U * .95 - h); ctx.lineTo(bx + U * .24, y0 + U * .95); ctx.fill();
      }
    } else if (ch === '_') {
      ctx.fillStyle = '#030102'; ctx.fillRect(x0 + U * .04, y0 + U * .04, U * .92, U * .92);
      ctx.fillStyle = '#24121a'; ctx.fillRect(x0 + U * .04, y0 + U * .04, U * .92, U * .14);
      if (held) softGlow(cx, cy + U * .1 + Math.sin(time * 1.4) * U * .06, U * .35, ELC[held], .3);
    } else if (ch === '^') {
      softGlow(cx, cy, U * .8, '#ff5a1f', .35);
      for (let k = 0; k < 3; k++) {
        const h = U * (.5 + .12 * Math.sin(time * (7 + k) + k)), w = U * (.16 - k * .03);
        ctx.fillStyle = ['#c8283c', '#ee7a3a', '#ffd27a'][k];
        ctx.beginPath(); ctx.moveTo(cx - w * 2, cy + U * .38); ctx.quadraticCurveTo(cx - w, cy - h * .3, cx + Math.sin(time * 3 + k) * U * .06, cy + U * .38 - h);
        ctx.quadraticCurveTo(cx + w, cy - h * .3, cx + w * 2, cy + U * .38); ctx.fill();
      }
    } else if (ch === '~') {
      const g = ctx.createLinearGradient(x0, y0, x0, y0 + U);
      g.addColorStop(0, '#3a7fa4'); g.addColorStop(1, '#0d2a3d');
      ctx.fillStyle = g; ctx.fillRect(x0 + U * .04, y0 + U * .04, U * .92, U * .92);
    }
    ctx.restore();
  }

  function heartDraw(dt) {
    const R = heart.R, S = heart.S, W = R.W, H = R.H;
    ctx.fillStyle = '#0c0708'; ctx.fillRect(0, 0, W * U, H * U);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const k = x + ',' + y;
      const old = heart.oldCells.get(k);
      const ch = old ? old.ch : S.cells[y][x];
      if (ch === '#' || ch === 'B') { wallTile(x, y); continue; }
      floorTile(x, y);
      if (R.cells[y][x] === 'S') {
        const cx = hc(x), cy = hc(y);
        softGlow(cx, cy, U * .7, GOLD, .12);
        for (const s of [-1, 1]) {
          ctx.fillStyle = '#3a2c2c'; ctx.beginPath();
          ctx.arc(cx + s * U * .05, cy, U * .38, s < 0 ? Math.PI / 2 : -Math.PI / 2, s < 0 ? Math.PI * 1.5 : Math.PI / 2); ctx.fill();
        }
        ctx.strokeStyle = rgba(GOLD, .5); ctx.lineWidth = Math.max(1, U * .03);
        ctx.beginPath(); ctx.arc(cx, cy, U * .38, 0, Math.PI * 2); ctx.stroke();
      }
      if (old) {
        // What was broken stays until the power reaches it, then goes.
        const a = old.t < 0 ? 1 : Math.max(0, 1 - old.t / .8);
        obstacle(old.ch, x, y, a, old.held);
        if (old.t >= 0) { old.t += dt; if (old.t > .8) heart.oldCells.delete(k); }
      } else obstacle(ch, x, y, 1, S.holds[k]);
    }
    // the altars: two stones, the front one notched the way its power goes
    for (const A of R.altars) {
      for (const [sx, sy, front] of [[A.back[0], A.back[1], false], [A.front[0], A.front[1], true]]) {
        const cx = hc(sx), cy = hc(sy);
        softGlow(cx, cy, U * .6, BLOOD, .1);
        ctx.fillStyle = front ? '#4a3034' : '#3a2629';
        ctx.beginPath(); ctx.ellipse(cx, cy + U * .05, U * .4, U * .34, 0, 0, Math.PI * 2); ctx.fill();
        ctx.strokeStyle = rgba(GOLD, .55); ctx.lineWidth = Math.max(1.5, U * .04); ctx.stroke();
        if (front) {
          ctx.fillStyle = rgba(GOLD, .7);
          ctx.beginPath(); ctx.moveTo(cx + U * .32, cy - U * .1); ctx.lineTo(cx + U * .46, cy + U * .05); ctx.lineTo(cx + U * .32, cy + U * .2); ctx.fill();
        }
      }
    }
    // Blood, bound in its niche — or let go
    const [bx, by] = R.blood;
    const bcx = hc(bx), bcy = hc(by);
    const bound = heart.capture < 0 || heart.capture > 3.4;
    if (bound && !heart.reformed) {
      bloodBody(bcx, bcy, U * .3);
      const gone = heart.freedT < 0 ? 0 : Math.min(1, heart.freedT / 1.0);
      if (gone < 1) {
        ctx.save(); ctx.globalAlpha = 1 - gone;
        ctx.strokeStyle = rgba(BLOOD, .9); ctx.lineWidth = Math.max(2, U * .08);
        for (const k of [-.4, .4]) { ctx.beginPath(); ctx.ellipse(bcx + k * U * (.3 + gone), bcy, U * .12, U * .46, k * .5, 0, Math.PI * 2); ctx.stroke(); }
        ctx.restore();
      }
    }
    // powers (under the bodies)
    for (let i = heart.fx.length - 1; i >= 0; i--) {
      const f = heart.fx[i];
      f.t += dt;
      if (f.kind === 'power') drawPower(f);
      if (f.t > f.dur) heart.fx.splice(i, 1);
    }
    // the creatures
    for (const c of S.cs) {
      if (heart.hide.has(c)) continue;
      let p = heart.pos.get(c);
      if (!p) { p = [c.at[0], c.at[1]]; heart.pos.set(c, p); }
      const e = Math.min(1, dt * 16);
      p[0] += (c.at[0] - p[0]) * e; p[1] += (c.at[1] - p[1]) * e;
      if (c.formT != null && c.formT < .5) c.formT += dt;
      const grow = c.formT == null ? 1 : Math.max(0, Math.min(1, c.formT / .5));
      const cx = hc(p[0]), cy = hc(p[1]), r = U * .3 * grow;
      if (r < 1) continue;
      creature(cx, cy, c.el, r);
      if (heart.sel === c) {
        ctx.strokeStyle = GOLD; ctx.lineWidth = Math.max(2, U * .05);
        ctx.beginPath(); ctx.arc(cx, cy, r + U * .1, 0, Math.PI * 2); ctx.stroke();
      }
      ctx.fillStyle = 'rgba(238,227,211,.85)';
      ctx.font = `500 ${Math.max(8, U * .17)}px ${getComputedStyle(document.body).fontFamily}`;
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText(heartName(c), cx, cy + r + U * .2);
    }
    for (const f of heart.fx) if (f.kind !== 'power') drawFuse(f);
    heartWalkTick(dt);
    if (heart.capture >= 0) heartCapture(dt);
    if (heart.freedT >= 0) heartFreed(dt);
  }

  // A fusion: the two spiral into the front stone, shedding grains, and what
  // they make grows there out of its own colour.
  function drawFuse(f) {
    const k = Math.min(1, f.t / .7);
    if (f.kind === 'fuse') {
      const fx = hc(f.at[0]), fy = hc(f.at[1]);
      f.from.forEach(([el, x, y], i) => {
        if (k >= 1) return;
        const ang = (1 - k) * 2.2 + i * Math.PI, rad = (1 - k) * Math.hypot(hc(x) - fx, hc(y) - fy);
        const px = fx + Math.cos(ang) * rad, py = fy + Math.sin(ang) * rad;
        creature(px, py, el, U * .3 * (1 - k * .6), 1 - k * .7);
        if (Math.random() < .8) particles.push({ x: px, y: py, vx: (Math.random() - .5) * U, vy: (Math.random() - .5) * U, life: 0, max: .6 + Math.random() * .5, col: ELC[el], sw: Math.random() * 6 });
      });
      const s = Math.sin(Math.max(0, Math.min(1, (f.t - .45) / .65)) * Math.PI);
      if (s > 0) softGlow(fx, fy, U * (.6 + .6 * s), ELC[f.el], .35 * s);
    } else if (f.kind === 'split') {
      const sx = hc(f.at[0]), sy = hc(f.at[1]);
      if (k < 1) { creature(sx, sy, f.el, U * .3 * (1 + k * .3), 1 - k); softGlow(sx, sy, U * .9, GOLD, .25 * (1 - k)); }
    } else if (f.kind === 'fizzle') {
      softGlow(hc(f.at[0]), hc(f.at[1]), U * .7, '#888888', .25 * (1 - k));
    }
  }

  // EVERY ELEMENT SHOWS ITSELF (the author, 2026-10-06: no "it breaks against
  // the wall" — "if we form a crystal fusion, crystals form on the other
  // side or something visually cool, and if it happens to solve it then
  // something else happens"). As it forms, the element runs out across the
  // room in its own way — crystals grow, lava pours, steam rolls, a wave
  // breaks — up to the first thing in the way. If that thing gives way to
  // it, it goes and what it held steps out. If not, the show simply ends.
  // Nothing is said either way.
  const SPEED = { Lightning: 30, Light: 22, Air: 14, Steam: 6, Dust: 7, Fire: 8, Water: 7, Spirit: 4.5,
    Dark: 4.5, Poison: 4.5, Ice: 6, Crystal: 4.5, Lava: 3.5, Mud: 3, Earth: 6, Plant: 4 }; // squares a second
  const T0 = .55, HOLD = .6, FADE = .7;
  function powerReach(run) { return run.hit ? (run.path.length + .5) * U : Math.max(U, run.path.length * U); }
  function powerTravel(run, el) { return Math.max(.18, powerReach(run) / U / (SPEED[el] || 6)); }
  const hz = (i, s = 0) => hash(i, s, 11);
  const MANIFEST = {
    Crystal(r) {
      for (let i = 0; ; i++) {
        const x = U * .45 + i * U * .3;
        if (x > r) break;
        const g = Math.min(1, (r - x) / (U * .6));
        for (const y of [-.18, .16]) {
          const h = U * (.25 + .5 * hz(i, y > 0 ? 1 : 2)) * g, w = U * .09, lean = (hz(i, 3) - .5) * U * .2;
          const gr = ctx.createLinearGradient(x, U * .3, x + lean, U * .3 - h);
          gr.addColorStop(0, '#5a3fa8'); gr.addColorStop(1, '#f1eaff');
          ctx.fillStyle = gr;
          ctx.beginPath(); ctx.moveTo(x - w, y * U + U * .22); ctx.lineTo(x + lean, y * U + U * .22 - h); ctx.lineTo(x + w, y * U + U * .22); ctx.fill();
        }
        if (hz(i, 4) > .7) softGlow(x, -U * .1, U * .25, '#e6dcff', .4 * g);
      }
    },
    Ice(r) {
      ctx.fillStyle = 'rgba(190,232,248,.25)'; ctx.fillRect(0, -U * .42, r, U * .84);
      for (let i = 0; ; i++) {
        const x = U * .3 + i * U * .16;
        if (x > r) break;
        const y = (hz(i, 1) - .5) * U * .7, h = U * (.08 + .14 * hz(i, 2));
        ctx.fillStyle = hz(i, 3) > .5 ? '#e8f8fd' : '#9fd8ec';
        ctx.beginPath(); ctx.moveTo(x - U * .05, y + h * .3); ctx.lineTo(x, y - h); ctx.lineTo(x + U * .05, y + h * .3); ctx.fill();
      }
    },
    Steam(r, L, k, t) {
      for (let i = 0; ; i++) {
        const x = i * U * .38;
        if (x > r) break;
        const age = (r - x) / U;
        for (let j = 0; j < 3; j++) {
          const rr = U * (.16 + .14 * Math.min(1, age) + .05 * j);
          ctx.fillStyle = `rgba(226,230,234,${.22 - j * .05})`;
          ctx.beginPath(); ctx.arc(x + j * U * .1, -age * U * .18 - j * U * .12 + Math.sin(t * 2 + i) * U * .05, rr, 0, Math.PI * 2); ctx.fill();
        }
      }
    },
    Lava(r, L, k, t) { tongue(r, t, ['#3a1006', '#c8380e', '#ff7a2a', '#ffd27a'], .24, .05); },
    Mud(r, L, k, t) { tongue(r, t, ['#24160c', '#4a3220', '#6a4a2c', '#9a7448'], .3, .09); },
    Water(r, L, k, t) {
      const back = Math.max(0, r - U * 2.2);
      const gr = ctx.createLinearGradient(back, 0, r, 0);
      gr.addColorStop(0, 'rgba(40,110,170,0)'); gr.addColorStop(.7, 'rgba(60,140,200,.75)'); gr.addColorStop(1, 'rgba(150,210,240,.9)');
      ctx.fillStyle = gr;
      ctx.beginPath(); ctx.moveTo(back, -U * .32);
      for (let x = back; x <= r; x += U * .1) ctx.lineTo(x, -U * .32 + Math.sin(t * 5 + x * .08) * U * .04);
      ctx.lineTo(r + U * .12, 0); ctx.lineTo(r, U * .32); ctx.lineTo(back, U * .32); ctx.fill();
      for (let i = 0; i < 6; i++) { ctx.fillStyle = 'rgba(240,250,255,.8)'; ctx.beginPath(); ctx.arc(r + U * .05 - hz(i) * U * .2, (hz(i, 1) - .5) * U * .6, U * .04, 0, Math.PI * 2); ctx.fill(); }
    },
    Fire(r, L, k, t) {
      for (let i = 0; ; i++) {
        const x = U * .3 + i * U * .28;
        if (x > r) break;
        const h = U * (.3 + .25 * hz(i)) * (1 + .2 * Math.sin(t * 9 + i)) * Math.min(1, (r - x) / (U * .4) + .2);
        for (const [c, s] of [['#c8283c', 1], ['#ee7a3a', .75], ['#ffd27a', .45]]) {
          ctx.fillStyle = c;
          ctx.beginPath(); ctx.moveTo(x - U * .12 * s, U * .25); ctx.quadraticCurveTo(x - U * .1 * s, U * .25 - h * .5 * s, x + Math.sin(t * 4 + i) * U * .05, U * .25 - h * s);
          ctx.quadraticCurveTo(x + U * .1 * s, U * .25 - h * .5 * s, x + U * .12 * s, U * .25); ctx.fill();
        }
      }
    },
    Dust(r, L, k, t) {
      for (let i = 0; i < 40; i++) {
        const x = hz(i) * r, a = t * 3 + i;
        ctx.fillStyle = i % 3 ? 'rgba(216,185,138,.7)' : 'rgba(170,140,100,.6)';
        ctx.fillRect(x + Math.cos(a) * U * .2, Math.sin(a * 1.3) * U * .35, 2.5, 2.5);
      }
      for (let i = 0; i * U * .5 < r; i++) softGlow(i * U * .5, Math.sin(t * 2 + i) * U * .1, U * .45, '#d8b98a', .18);
    },
    Earth(r) {
      for (let i = 0; ; i++) {
        const x = U * .4 + i * U * .34;
        if (x > r) break;
        const g = Math.min(1, (r - x) / (U * .4)), h = U * (.2 + .35 * hz(i)) * g, w = U * (.12 + .06 * hz(i, 1));
        ctx.fillStyle = hz(i, 2) > .5 ? '#8a6a46' : '#6a5038';
        ctx.beginPath(); ctx.moveTo(x - w, U * .3); ctx.lineTo(x - w * .4, U * .3 - h); ctx.lineTo(x + w * .5, U * .3 - h * .85); ctx.lineTo(x + w, U * .3); ctx.fill();
      }
    },
    Spirit(r, L, k, t) {
      for (let i = 0; i < 6; i++) {
        const x = r - i * U * .45;
        if (x < 0) break;
        softGlow(x, Math.sin(t * 3 + i * 1.7) * U * .25, U * .3, '#e6e0ff', .45 - i * .06);
      }
    },
    Light(r) {
      const gr = ctx.createLinearGradient(0, -U * .2, 0, U * .2);
      gr.addColorStop(0, 'rgba(255,240,176,0)'); gr.addColorStop(.5, 'rgba(255,248,220,.9)'); gr.addColorStop(1, 'rgba(255,240,176,0)');
      ctx.fillStyle = gr; ctx.fillRect(0, -U * .2, r, U * .4);
      softGlow(r, 0, U * .6, '#fff0b0', .5);
    },
    Dark(r, L, k, t) {
      const gr = ctx.createLinearGradient(0, -U * .45, 0, U * .45);
      gr.addColorStop(0, 'rgba(20,8,30,0)'); gr.addColorStop(.5, 'rgba(20,8,30,.85)'); gr.addColorStop(1, 'rgba(20,8,30,0)');
      ctx.fillStyle = gr; ctx.fillRect(0, -U * .45, r, U * .9);
      for (let i = 0; i < 10; i++) softGlow(hz(i) * r, Math.sin(t * 2 + i) * U * .3, U * .12, '#7a5aa8', .5);
    },
    Poison(r, L, k, t) {
      for (let i = 0; ; i++) {
        const x = i * U * .22;
        if (x > r) break;
        const life = ((t * .8 + hz(i)) % 1), rr = U * (.05 + .1 * hz(i, 1)) * (1 + life);
        ctx.fillStyle = `rgba(134,201,74,${.55 * (1 - life)})`;
        ctx.beginPath(); ctx.arc(x, (hz(i, 2) - .5) * U * .6 - life * U * .3, rr, 0, Math.PI * 2); ctx.fill();
      }
      softGlow(r, 0, U * .5, '#86c94a', .25);
    },
    Plant(r, L, k, t) {
      ctx.fillStyle = '#3f7a32';
      for (let x = 0; x < r; x += U * .06) { const y = Math.sin(x * .09) * U * .18; ctx.fillRect(x, y - U * .04, U * .07, U * .08); }
      for (let i = 0; ; i++) {
        const x = U * .3 + i * U * .35;
        if (x > r) break;
        const y = Math.sin(x * .09) * U * .18, s = i % 2 ? 1 : -1;
        ctx.fillStyle = '#5fb04a';
        ctx.beginPath(); ctx.ellipse(x, y + s * U * .12, U * .1, U * .05, s * .6, 0, Math.PI * 2); ctx.fill();
      }
    },
    Air(r, L, k, t) {
      for (let i = 0; i < 5; i++) {
        const x = r - i * U * .5;
        if (x < 0) break;
        ctx.fillStyle = `rgba(220,235,242,${.5 - i * .08})`;
        ctx.beginPath(); ctx.ellipse(x, (i % 2 ? -1 : 1) * U * .15, U * .3, U * .05, 0, 0, Math.PI * 2); ctx.fill();
      }
    },
    Lightning(r, L, k, t) {
      ctx.strokeStyle = 'rgba(255,248,180,.95)'; ctx.lineWidth = Math.max(2, U * .06); ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(0, 0);
      const n = Math.max(3, Math.round(r / (U * .3)));
      for (let i = 1; i <= n; i++) ctx.lineTo(r * i / n, i < n ? (Math.random() - .5) * U * .4 : 0);
      ctx.stroke();
      softGlow(r, 0, U * .5, '#f2e36a', .4);
    },
  };
  // Lava and mud: a tongue that pours along the floor, bright at its front
  // and darkening behind as it cools (or thickens).
  function tongue(r, t, cols, half, lump) {
    if (r < 2) return;
    const gr = ctx.createLinearGradient(0, 0, r, 0);
    gr.addColorStop(0, cols[0]); gr.addColorStop(.5, cols[1]); gr.addColorStop(.85, cols[2]); gr.addColorStop(1, cols[3]);
    ctx.fillStyle = gr;
    ctx.beginPath(); ctx.moveTo(0, -U * half);
    for (let x = 0; x <= r; x += U * .1) ctx.lineTo(x, -U * half + Math.sin(x * .2 + t) * U * lump);
    ctx.quadraticCurveTo(r + U * .25, 0, r, U * half);
    for (let x = r; x >= 0; x -= U * .1) ctx.lineTo(x, U * half + Math.sin(x * .17 - t) * U * lump);
    ctx.fill();
  }

  function drawPower(f) {
    const run = f.run, d = f.A.d;
    if (f.t < T0) return;
    const L = powerReach(run), travel = powerTravel(run, f.el);
    const k = Math.min(1, (f.t - T0) / travel);
    const after = f.t - T0 - travel;
    const a = after <= HOLD ? 1 : Math.max(0, 1 - (after - HOLD) / FADE);
    const e = 1 - (1 - k) * (1 - k);
    if (a > .01) {
      ctx.save();
      ctx.translate(hc(f.A.front[0]), hc(f.A.front[1]));
      ctx.rotate(Math.atan2(HR.DY[d], HR.DX[d]));
      ctx.globalAlpha = a;
      (MANIFEST[f.el] || ((r) => softGlow(r, 0, U * .5, ELC[f.el] || GOLD, .5)))(L * e, L, k, time);
      ctx.restore();
    }
    if (k >= 1 && !f.landed) {
      f.landed = true;
      if (run.broke) {
        // It was what this thing gives way to: it goes, and what it held
        // steps out.
        for (const [x, y] of run.changed) {
          const o = heart.oldCells.get(x + ',' + y);
          if (o) o.t = 0;
          release(hc(x), hc(y), ELC[f.el] || GOLD, 50);
        }
        for (const c of f.freed) { heart.hide.delete(c); c.formT = -.2; }
      }
    }
  }

  // ── play ──
  function heartBusy() { return heart.walk || heart.fx.length || heart.capture >= 0 || heart.freedT >= 0; }
  function heartTap(e) {
    if (heartBusy()) return;
    const [x, y] = heartCell(e);
    const S = heart.S;
    const here = S.cs.filter((c) => c.at[0] === x && c.at[1] === y);
    if (here.length && (!heart.sel || !here.includes(heart.sel) || here.length > 1)) {
      const i = heart.sel ? (here.indexOf(heart.sel) + 1) % here.length : 0;
      heart.sel = here[Math.max(0, i)];
      say(`${heartName(heart.sel)}. Tap where it should go.`);
      return;
    }
    if (!heart.sel) { say('Tap one of them first.'); return; }
    if (heart.sel.at[0] === x && heart.sel.at[1] === y) { heart.sel = null; say(''); return; }
    const p = HR.path(heart.R, S.cells, heart.sel.at, [x, y]);
    if (!p) { say('It can\'t get there.'); return; }
    heart.walk = { c: heart.sel, path: p, i: 0, t: 0 };
  }
  function heartStep(d) {
    if (heartBusy() || !heart.sel) return;
    const c = heart.sel, nx = c.at[0] + HR.DX[d], ny = c.at[1] + HR.DY[d];
    if (!HR.walkable(heart.R, heart.S.cells, nx, ny)) return;
    heart.walk = { c, path: [c.at.slice(), [nx, ny]], i: 0, t: 0 };
  }
  function heartWalkTick(dt) {
    const w = heart.walk;
    if (!w) return;
    w.t += dt * 8;
    while (w.t >= 1 && w.i < w.path.length - 1) { w.t -= 1; w.i++; w.c.at = w.path[w.i].slice(); }
    if (w.i >= w.path.length - 1) { heart.walk = null; heartArrive(w.c); }
  }
  function heartArrive(c) {
    const R = heart.R, S = heart.S;
    R.altars.forEach((A, ai) => {
      const onBack = c.at[0] === A.back[0] && c.at[1] === A.back[1];
      const onFront = c.at[0] === A.front[0] && c.at[1] === A.front[1];
      if (!onBack && !onFront) return;
      const other = A[onBack ? 'front' : 'back'];
      const o = S.cs.find((q) => q !== c && q.at[0] === other[0] && q.at[1] === other[1]);
      if (!o) return;
      const i = S.cs.indexOf(onBack ? c : o), j = S.cs.indexOf(onBack ? o : c);
      const r = HR.fuse(R, S, ai, i, j);
      if (r.why) { heart.fx.push({ kind: 'fizzle', at: A.front, t: 0, dur: .6 }); say(r.why + '.'); return; }
      for (const [x, y] of r.run.changed) heart.oldCells.set(x + ',' + y, { ch: S.cells[y][x], t: -1, held: S.holds[x + ',' + y] });
      const from = [[S.cs[i].el, ...S.cs[i].at], [S.cs[j].el, ...S.cs[j].at]];
      heart.S = r.S;
      r.made.formT = -.45;
      heart.pos.set(r.made, A.front.slice());
      heart.sel = r.made;
      for (const fc of r.freed) { heart.hide.add(fc); heart.pos.set(fc, fc.at.slice()); }
      heart.fx.push({ kind: 'fuse', at: A.front, from, el: r.made.el, t: 0, dur: 1.2 });
      say(`${from[0][0]} and ${from[1][0]} make ${r.made.el}.`);
      if (r.blood) { heartBlood(r.made); return; }
      heart.fx.push({ kind: 'power', A, run: r.run, el: r.made.el, freed: r.freed, t: 0, dur: T0 + powerTravel(r.run, r.made.el) + HOLD + FADE });
    });
    if (R.cells[c.at[1]][c.at[0]] === 'S' && c.parts) {
      const i = S.cs.indexOf(c);
      const r = HR.split(R, S, i, c.at[0], c.at[1]);
      heart.S = r.S;
      const [p, q] = r.S.cs.slice(-2);
      heart.names.set(p, heartName(c.parts[0])); heart.names.set(q, heartName(c.parts[1]));
      p.formT = -.3; q.formT = -.3;
      heart.pos.set(p, c.at.slice()); heart.pos.set(q, c.at.slice());
      heart.sel = null;
      heart.fx.push({ kind: 'split', at: c.at.slice(), el: c.el, t: 0, dur: .8 });
      say(`${c.el} comes apart into ${c.parts[0].el} and ${c.parts[1].el}.`);
    }
  }

  // BLOOD: the made Blood pours across the room into the one that was taken,
  // and its bands let go.
  function heartBlood(made) {
    heart.sel = null;
    heart.bloodFlow = { from: made, t: 0 };
    heart.freedT = 0;
    say('Light and Dark make Blood.');
  }
  function heartFreed(dt) {
    heart.freedT += dt;
    const t = heart.freedT;
    const [bx, by] = heart.R.blood;
    const fl = heart.bloodFlow;
    if (fl && t < 2.2) {
      const p = heart.pos.get(fl.from) || fl.from.at;
      const k = Math.min(1, Math.max(0, (t - .8) / 1.2));
      if (t > .8) {
        heart.hide.add(fl.from);
        const sx = hc(p[0]), sy = hc(p[1]), ex = hc(bx), ey = hc(by);
        for (let i = 0; i < 6; i++) {
          const tt = Math.max(0, k - Math.random() * .3);
          particles.push({ x: sx + (ex - sx) * tt + (Math.random() - .5) * U * .3, y: sy + (ey - sy) * tt - Math.sin(tt * Math.PI) * U * 1.2, vx: 0, vy: 0, life: 0, max: .5, col: i % 3 ? BLOOD : '#ff8a94', sw: Math.random() * 6 });
        }
      }
    }
    if (t > 2.4 && !heart.reformed) {
      heart.reformed = true;
      release(hc(bx), hc(by), BLOOD, 120);
      for (const c of heart.S.cs) if (!heart.hide.has(c)) release(hc(c.at[0]), hc(c.at[1]), ELC[c.el], 30);
      // Blood steps out onto the stage; the four re-form round it.
      const at = [3, 4];
      heart.S.cs = [{ el: 'Blood', parts: null, at, formT: -.3 }].concat(HR.BASE.map((el, i) => ({ el, parts: null, at: [[2, 4], [4, 4], [3, 3], [3, 5]][i], formT: -.5 - i * .15 })));
      heart.hide = new Set();
      heart.S.cs.forEach((c) => { heart.names.set(c, c.el === 'Blood' ? 'Your Blood' : c.el + 'kin'); heart.pos.set(c, c.at.slice()); });
      say('Your Blood is free. The four re-form beside it, and the floor opens on Sanguorath.');
      if (!heartDone) { heartDone = true; try { localStorage.setItem('blood-rites-heart', '1'); } catch (e) {} }
      renderChrome();
    }
    if (t > 4) heart.freedT = 4;
  }

  // THE CAPTURE (a sketch of the game's cutscene): Blood steps into the Heart,
  // comes apart into grains, and the grains are drawn into the niche and
  // bound; then the four pour in, each in its own colour, and stand.
  function heartCapture(dt) {
    const t = heart.capture += dt;
    const [bx, by] = heart.R.blood;
    const sx = hc(3), sy = hc(4);
    if (t < 1.0) { bloodBody(sx, sy, U * .3); say('Blood steps into the Heart.'); }
    else if (t < 1.1) { release(sx, sy, BLOOD, 120); say('It comes apart, and it is taken.'); }
    else if (t < 3.4) {
      const k = (t - 1.1) / 2.3;
      for (let i = 0; i < 3; i++) particles.push({ x: sx + (hc(bx) - sx) * k + (Math.random() - .5) * U * .8, y: sy + (hc(by) - sy) * k - Math.sin(k * Math.PI) * U + (Math.random() - .5) * U * .8, vx: 0, vy: 0, life: 0, max: .5, col: BLOOD, sw: Math.random() * 6 });
    }
    heart.hide = new Set(heart.S.cs.filter((c, i) => t < 3.6 + i * .35));
    if (t > 3.4 && t < 5.4) {
      heart.S.cs.forEach((c, i) => {
        const k = t - 3.6 - i * .35;
        if (k > 0 && k < .4) for (let n = 0; n < 4; n++) particles.push({ x: hc(c.at[0]) + (Math.random() - .5) * U * .6, y: hc(c.at[1]) + (Math.random() - .5) * U * .6, vx: 0, vy: 0, life: 0, max: .5, col: ELC[c.el], sw: Math.random() * 6 });
      });
      say('The four you freed pour in after it.');
    }
    if (t > 5.4) { heart.capture = -1; heart.hide = new Set(); say('Tap one of the four, then tap where it should go.'); }
  }
  // A test seam: tap square (x, y) as a finger would.
  window.__heartTap = (x, y) => {
    const r = cv.getBoundingClientRect();
    heartTap({ clientX: r.left + (x + .5) * U, clientY: r.top + (y + .5) * U });
    return document.getElementById('status').textContent;
  };
