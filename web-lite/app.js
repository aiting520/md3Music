/* ============================================================
 *  app.js — 播放核心 / Folia 歌词引擎 / 液态滑块
 *  零依赖。所有动画共用一条 rAF 时钟。
 * ============================================================ */
(() => {
  'use strict';

  const $  = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const clamp = (v, a = 0, b = 1) => v < a ? a : v > b ? b : v;
  const fmt = s => {
    s = Math.max(0, Math.floor(s));
    return (s / 60 | 0) + ':' + String(s % 60).padStart(2, '0');
  };

  /* ---------- 全局状态 ---------- */
  const S = {
    idx: 0,             // 当前歌曲
    t: 0,               // 播放时间(秒)
    playing: true,
    dur: 0,
    rows: [],           // 行 DOM
    linePos: [],        // 行中心(px, 相对 track)
    active: -1,
    spring: { p: 0, v: 0 },
    prevIdx: -1,
  };

  const FEAT = { glass: true, sheen: true, karaoke: true, spring: true };

  /* ---------- DOM ---------- */
  const track     = $('#track');
  const wrap      = $('#lyricWrap');
  const fill      = $('#fill');
  const ringFill  = $('#ringFill');
  const tCur      = $('#tCur');
  const tDur      = $('#tDur');
  const blob      = $('#blob');
  const nav       = $('#nav');
  const items     = $$('.nav .item');
  const mPlay     = $('#mPlay');

  /* ============================================================
   *  1. 歌词构建:把 [{t,d,w:[...]}] 展开成逐字时间轴
   * ============================================================ */
  function timeline(song) {
    return song.lines.map(L => {
      let cur = L.t;
      const words = L.w.map(w => {
        const c = typeof w === 'string' ? w : w.c;
        const d = typeof w === 'string' ? L.d : (w.d ?? L.d);
        const o = { c, s: cur, e: cur + d };
        cur += d;
        return o;
      });
      return { start: L.t, end: cur, words };
    });
  }

  /* 渲染整首歌词 */
  function renderLyrics() {
    const song = LYRICS[S.idx];
    const lines = timeline(song);
    S.rows = [];
    S.active = -1;
    track.innerHTML = '';
    S.dur = Math.ceil(lines[lines.length - 1].end + 3.5);

    lines.forEach((L, i) => {
      // 间奏点:与上一行间隔够长就插一段跳动的点
      if (i > 0) {
        const gap = L.start - lines[i - 1].end;
        if (gap > 2.05) {
          const dots = document.createElement('div');
          dots.className = 'interlude';
          dots.innerHTML = '<i></i><i></i><i></i>';
          track.appendChild(dots);
        }
      }

      const el = document.createElement('div');
      el.className = 'line';
      el.dataset.i = i;
      el.dataset.st = 'future';
      const inner = document.createElement('span');
      inner.className = 'inner';

      L.words.forEach((w, k) => {
        const s = document.createElement('span');
        s.className = 'w';
        s.textContent = w.c;
        s.dataset.s = w.s;
        s.dataset.e = w.e;
        s.dataset.k = k;
        s.style.setProperty('--p', 0);
        inner.appendChild(s);
      });

      el.appendChild(inner);
      track.appendChild(el);
      S.rows.push({ el, L, words: L.words, els: [...inner.children] });
    });

    $('#nowTitle').textContent = song.title;
    $('#nowArtist').textContent = song.artist + ' · ' + song.album;
    $('#miniTitle').textContent = song.title;
    $('#miniSub').textContent = song.artist + ' · ' + song.album;
    $('#tDur').textContent = fmt(S.dur);
    document.documentElement.style.setProperty('--hue', song.hue);

    // 等一帧让布局落地再量行位置
    requestAnimationFrame(measure);
  }

  function measure() {
    S.linePos = S.rows.map(r => r.el.offsetTop + r.el.offsetHeight / 2);
    if (S.active >= 0) snapScroll();
  }

  /* ============================================================
   *  2. 每帧:算行状态 + 逐字进度
   * ============================================================ */
  function updateLyrics() {
    const t = S.t;
    let idx = -1;
    for (let i = 0; i < S.rows.length; i++) {
      if (t >= S.rows[i].L.start) idx = i; else break;
    }
    if (idx === -1) idx = 0;

    if (idx !== S.active) {
      // 旧行退场 + 之前的行全部钉满
      for (let i = 0; i < idx; i++) {
        if (S.rows[i].el.dataset.st === 'past') continue;
        S.rows[i].el.dataset.st = 'past';
        S.rows[i].els.forEach(w => {
          w.dataset.p = 1; w.style.setProperty('--p', 1); w.dataset.live = 0;
        });
      }
      S.active = idx;
      const row = S.rows[idx];
      row.el.dataset.st = 'now';
      // 字入场微动(只做一次)
      S.spring.target = -(S.linePos[idx] ?? 0);
    }

    // 逐字扫描:只碰当前行,过去行钉在 1
    for (let i = Math.max(0, idx - 1); i <= idx; i++) {
      const row = S.rows[i];
      if (!row) continue;
      const ended = i < idx;
      row.els.forEach(w => {
        const s = +w.dataset.s, e = +w.dataset.e;
        let p = ended ? 1 : clamp((t - s) / (e - s));
        const prev = +(w.dataset.p || 0);
        if (Math.abs(p - prev) > 0.004 || (p === 1 && prev !== 1)) {
          w.dataset.p = p;
          w.style.setProperty('--p', p.toFixed(3));
        }
        if (FEAT.karaoke) w.dataset.live = (p > 0 && p < 1) ? 1 : 0;
      });
    }

    // 未来行归零(切歌/回跳时)
    for (let i = idx + 1; i < S.rows.length; i++) {
      const ws = S.rows[i].els;
      if (ws.length && ws[0].dataset.p && +ws[0].dataset.p !== 0) {
        ws.forEach(w => { w.dataset.p = 0; w.style.setProperty('--p', 0); w.dataset.live = 0; });
      }
    }
  }

  /* ============================================================
   *  3. 弹簧滚动
   * ============================================================ */
  function stepSpring(dt) {
    const sp = S.spring;
    if (!FEAT.spring) { sp.p = sp.target; sp.v = 0; }
    else {
      const k = 168, d = 24;           // 欠阻尼,收尾会轻轻回弹
      const a = (sp.target - sp.p) * k - sp.v * d;
      sp.v += a * dt;
      sp.p += sp.v * dt;
      if (Math.abs(sp.target - sp.p) < 0.05 && Math.abs(sp.v) < 0.05) {
        sp.p = sp.target; sp.v = 0;
      }
    }
    if (S._tp === undefined || Math.abs(sp.p - S._tp) > 0.05) {
      track.style.transform = `translate3d(0, ${sp.p.toFixed(2)}px, 0)`;
      S._tp = sp.p;
    }

    // 非当前行的缩放:离当前行越远越缩
    S.rows.forEach((r, i) => {
      const dist = i - S.active;
      const sc = dist === 0 ? 1.04 : dist < 0 ? 0.9 : 0.84;
      const el = r.el;
      if (el._sc !== sc) { el._sc = sc; el.style.transform = `scale(${sc})`; }
    });
  }

  function snapScroll() {
    S.spring.p = S.spring.target = -(S.linePos[S.active] ?? 0);
    S.spring.v = 0;
    track.style.transform = `translate3d(0, ${S.spring.p.toFixed(2)}px, 0)`;
  }

  /* ============================================================
   *  4. 播放时钟
   * ============================================================ */
  let last = performance.now();
  function loop(now) {
    const dt = Math.min((now - last) / 1000, 1 / 20);
    last = now;

    if (S.playing) {
      S.t += dt;
      if (S.t >= S.dur) { next(1); }
    }
    updateLyrics();
    stepSpring(dt);
    stepBlob(dt);

    const r = clamp(S.t / S.dur);
    fill.style.transform = `scaleX(${r})`;
    ringFill.style.transform = `scaleX(${r})`;
    tCur.textContent = fmt(S.t);
    requestAnimationFrame(loop);
  }

  /* ============================================================
   *  5. 切歌 / 播放控制
   * ============================================================ */
  function setSong(i, keepPlaying = true) {
    S.idx = (i + LYRICS.length) % LYRICS.length;
    S.t = 0;
    S.playing = keepPlaying;
    S.spring.p = 0; S.spring.v = 0; S.spring.target = 0;
    renderLyrics();
    syncPlayBtn();
  }
  const next = d => setSong(S.idx + d);

  function syncPlayBtn() {
    mPlay.innerHTML = `<svg><use href="#${S.playing ? 'i-pause' : 'i-playonly'}"/></svg>`;
  }

  mPlay.addEventListener('click', () => {
    S.playing = !S.playing;
    syncPlayBtn();
  });
  $('#mNext').addEventListener('click', () => next(1));
  $('#mPrev').addEventListener('click', () => next(-1));

  /* 点歌词跳转 */
  track.addEventListener('click', e => {
    const row = e.target.closest('.line');
    if (!row) return;
    const i = +row.dataset.i;
    S.t = Math.max(0, S.rows[i].L.start);
    S.active = -1;           // 强制刷新行状态
    updateLyrics();
    S.spring.target = -(S.linePos[i] ?? 0);
  });

  /* 进度条 */
  const rail = $('#rail');
  const seek = e => {
    const r = rail.getBoundingClientRect();
    S.t = clamp((e.clientX - r.left) / r.width) * S.dur;
    S.active = -1;
  };
  rail.addEventListener('pointerdown', e => {
    seek(e);
    const mv = ev => seek(ev);
    const up = () => {
      window.removeEventListener('pointermove', mv);
      window.removeEventListener('pointerup', up);
    };
    window.addEventListener('pointermove', mv);
    window.addEventListener('pointerup', up);
  });

  /* ============================================================
   *  6. 液态滑块
   * ============================================================ */
  const B = { x: 0, tx: 0, v: 0, w: 0, ready: false };

  function blobTarget(i, animate = true) {
    const it = items[i];
    const nr = nav.getBoundingClientRect();
    const ir = it.getBoundingClientRect();
    B.tx = ir.left - nr.left;
    B.w = ir.width;
    blob.style.width = B.w + 'px';
    if (!animate || !B.ready) {
      B.x = B.tx; B.v = 0; B.ready = true;
      drawBlob();
    }
  }

  function drawBlob() {
    // 速度 → 沿运动方向拉伸,形成液滴拖尾
    const stretch = clamp(Math.abs(B.v) / 2600, 0, 0.34);
    const dir = B.v >= 0 ? 1 : -1;
    blob.style.transformOrigin = dir > 0 ? '0% 50%' : '100% 50%';
    blob.style.transform = `translate3d(${B.x.toFixed(2)}px,0,0) scaleX(${(1 + stretch).toFixed(3)}) scaleY(${(1 - stretch * 0.35).toFixed(3)})`;
  }

  function stepBlob(dt) {
    const k = 220, d = 26;
    const a = (B.tx - B.x) * k - B.v * d;
    B.v += a * dt;
    B.x += B.v * dt;
    if (Math.abs(B.tx - B.x) < 0.15 && Math.abs(B.v) < 1.2) { B.x = B.tx; B.v = 0; }
    if (B._dr === undefined || Math.abs(B.x - B._dr) > 0.08 || B._st !== B.v) {
      drawBlob();
      B._dr = B.x; B._st = B.v;
    }
  }

  /* ============================================================
   *  7. 页面切换
   * ============================================================ */
  const pages = $$('.page');
  function go(name, i) {
    pages.forEach(p => p.classList.toggle('on', p.dataset.page === name));
    items.forEach((b, k) => b.setAttribute('aria-current', k === i ? 'true' : 'false'));
    blobTarget(i);
    if (name === 'play') requestAnimationFrame(measure);
  }
  items.forEach((b, i) => b.addEventListener('click', () => go(b.dataset.go, i)));

  /* 设置开关 */
  $$('.switch').forEach(sw => {
    sw.addEventListener('click', () => {
      const on = sw.dataset.on === '1' ? '0' : '1';
      sw.dataset.on = on;
      const k = sw.dataset.k;
      FEAT[k] = on === '1';
      document.body.classList.toggle('no-' + k, on !== '1');
      if (k === 'spring' && FEAT.spring) snapScroll();
      if (k === 'karaoke') {
        $$('.w').forEach(w => { if (!FEAT.karaoke) { w.style.setProperty('--p', 0); } });
        S.active = -1;
      }
    });
  });

  /* ============================================================
   *  8. 启动
   * ============================================================ */
  window.addEventListener('resize', () => {
    measure();
    blobTarget(items.findIndex(b => b.getAttribute('aria-current') === 'true'), false);
  });

  renderLyrics();
  requestAnimationFrame(() => {
    measure();
    blobTarget(2, false);          // 默认停在"播放"
    S.active = -1;
  });
  syncPlayBtn();
  requestAnimationFrame(loop);

  /* 字号 / 景深:点一下循环切换 */
  const FS = [24, 26, 28, 30, 32], DP = [1.2, 1.8, 2.4, 3.2];
  let fsi = 2, dpi = 2;
  $$('.set[data-tune]').forEach(el => el.addEventListener('click', () => {
    if (el.dataset.tune === 'fs') {
      fsi = (fsi + 1) % FS.length;
      document.documentElement.style.setProperty('--fs', FS[fsi] + 'px');
      $('#fsVal').textContent = FS[fsi];
    } else {
      dpi = (dpi + 1) % DP.length;
      document.documentElement.style.setProperty('--depth', DP[dpi] + 'px');
      $('#blurVal').textContent = DP[dpi];
    }
    requestAnimationFrame(() => { measure(); S.active = -1; updateLyrics(); });
  }));

  /* 调试/自动化接口 */
  window.__md3 = {
    seek(t) { S.t = t; S.active = -1; updateLyrics(); S.spring.target = -(S.linePos[S.active] || 0); },
    song(i) { setSong(i); },
    state() { return { t: S.t, idx: S.idx, active: S.active, dur: S.dur }; },
    feat(k, v) { FEAT[k] = v; document.body.classList.toggle('no-' + k, !v); },
  };

})();
