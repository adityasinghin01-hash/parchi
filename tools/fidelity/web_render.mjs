// Renders every HTML screen at 390x844 (3x) and writes, per route, into frontend/specs/web/:
//   <route>.png        viewport screenshot (1170x2532), the TARGET for the Swift app
//   <route>_full.png   full scrollable page
//   <route>.json       every visible element: rect (px and artboard units), text, typography, colours, radius, border, shadow,
//                      inline SVG icon markup, reference-art crops (which JPEG, which rectangle) and <img> logos.
// Usage (from the repo root, with the web preview served by:  cd frontend && python3 -m http.server 8765 --bind 127.0.0.1):
//   node tools/fidelity/web_render.mjs [route ...]
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
const require = createRequire(import.meta.url);
const PW = process.env.PLAYWRIGHT_CORE || '/Users/aditya/.npm/_npx/9833c18b2d85bc59/node_modules/playwright-core';
const { chromium } = require(PW);
const BASE = process.env.WEB_BASE || 'http://127.0.0.1:8765';
const OUT = path.resolve('frontend/specs/web');
fs.mkdirSync(OUT, { recursive: true });
const ALL = ['welcome', 'signin', 'verify', 'home', 'area', 'capture', 'reading', 'review', 'plans', 'plan-map', 'get-all', 'checkout', 'track', 'care', 'pass', 'history', 'account', 'ranking'];
const routes = process.argv.length > 2 ? process.argv.slice(2) : ALL;

const extract = () => {
  const W = innerWidth, U = W / 735, r1 = (n) => Math.round(n * 10) / 10;
  const rect = (r) => ({ x: r1(r.left + scrollX), y: r1(r.top + scrollY), w: r1(r.width), h: r1(r.height), xu: r1((r.left + scrollX) / U), yu: r1((r.top + scrollY) / U), wu: r1(r.width / U), hu: r1(r.height / U) });
  const root = document.querySelector('.phone-preview') || document.body;
  // CSS ::before / ::after are not DOM nodes: copy their computed style onto real inserted spans so they can be measured.
  for (const host of Array.from(root.querySelectorAll('*'))) {
    if (host.closest('svg')) continue;
    for (const which of ['before', 'after']) {
      const pcs = getComputedStyle(host, '::' + which);
      if (!pcs.content || pcs.content === 'none' || pcs.content === 'normal' || pcs.display === 'none') continue;
      const span = document.createElement('span'); span.className = '__pseudo ' + which;
      for (const prop of pcs) { try { span.style.setProperty(prop, pcs.getPropertyValue(prop)); } catch (err) {} }
      const m = pcs.content.match(/^"(.*)"$/); span.textContent = m ? m[1] : '';
      if (which === 'before') host.insertBefore(span, host.firstChild); else host.appendChild(span);
    }
  }
  const elements = [], art = [], images = [];
  const transparent = (c) => !c || c === 'rgba(0, 0, 0, 0)' || c === 'transparent';
  let order = 0;
  for (const el of root.querySelectorAll('*')) {
    const cs = getComputedStyle(el), r = el.getBoundingClientRect(), tag = el.tagName.toLowerCase();
    if (r.width < 0.5 || r.height < 0.5 || cs.visibility === 'hidden' || cs.display === 'none' || parseFloat(cs.opacity) === 0) continue;
    if (['path', 'rect', 'circle', 'line', 'polyline', 'polygon', 'g', 'defs', 'clippath', 'image', 'ellipse', 'use', 'mask', 'lineargradient', 'stop', 'tspan'].includes(tag)) continue;
    if (el.closest('svg') && el.closest('svg') !== el) continue;
    if (tag === 'svg' && el.classList.contains('reference-art')) {
      const im = el.querySelector('image');
      art.push({ mask: ((cs.webkitMaskImage || cs.maskImage) !== 'none' ? (cs.webkitMaskImage || cs.maskImage) : undefined), blend: cs.mixBlendMode !== 'normal' ? cs.mixBlendMode : undefined, filter: cs.filter !== 'none' ? cs.filter : undefined, z: (cs.position !== 'static' && cs.zIndex !== 'auto') ? parseInt(cs.zIndex) : 0, viewBox: el.getAttribute('viewBox'), href: im && (im.getAttribute('href') || im.getAttributeNS('http://www.w3.org/1999/xlink', 'href')), aspect: el.getAttribute('preserveAspectRatio'), cls: el.getAttribute('class'), rect: rect(r), order: order++ });
      continue;
    }
    if (tag === 'img') { images.push({ mask: ((cs.webkitMaskImage || cs.maskImage) !== 'none' ? (cs.webkitMaskImage || cs.maskImage) : undefined), blend: cs.mixBlendMode !== 'normal' ? cs.mixBlendMode : undefined, filter: cs.filter !== 'none' ? cs.filter : undefined, z: (cs.position !== 'static' && cs.zIndex !== 'auto') ? parseInt(cs.zIndex) : 0, src: el.getAttribute('src'), alt: el.getAttribute('alt'), rect: rect(r), radius: cs.borderRadius, order: order++ }); continue; }
    const ownText = Array.from(el.childNodes).map((n) => n.nodeType === 3 ? n.textContent.replace(/\s+/g, ' ') : (n.nodeName === 'BR' ? '\n' : '')).join('').replace(/ *\n */g, '\n').trim();
    const bg = transparent(cs.backgroundColor) ? null : cs.backgroundColor;
    const bgImg = cs.backgroundImage !== 'none' ? cs.backgroundImage.slice(0, 300) : null;
    const hasBorder = ['Top', 'Right', 'Bottom', 'Left'].some((s) => parseFloat(cs['border' + s + 'Width']) > 0 && cs['border' + s + 'Style'] !== 'none');
    const shadow = cs.boxShadow !== 'none' ? cs.boxShadow.slice(0, 200) : null;
    const isIcon = tag === 'svg';
    if (!(ownText || bg || bgImg || hasBorder || shadow || isIcon || ['input', 'button', 'hr', 'textarea', 'select'].includes(tag))) continue;
    const e = { mask: ((cs.webkitMaskImage || cs.maskImage) !== 'none' ? (cs.webkitMaskImage || cs.maskImage) : undefined), blend: cs.mixBlendMode !== 'normal' ? cs.mixBlendMode : undefined, filter: cs.filter !== 'none' ? cs.filter : undefined, z: (cs.position !== 'static' && cs.zIndex !== 'auto') ? parseInt(cs.zIndex) : 0, order: order++, tag, cls: (el.getAttribute('class') || '').slice(0, 80), id: el.id || undefined, rect: rect(r) };
    if (el.getAttribute('aria-label')) e.aria = el.getAttribute('aria-label');
    if (el.getAttribute('data-sf')) e.sf = el.getAttribute('data-sf');
    let fixed = false; for (let a = el; a && a !== document.body; a = a.parentElement) { if (getComputedStyle(a).position === 'fixed') { fixed = true; break; } }
    if (fixed) e.fixed = true;
    if (tag === 'input') { const pc = getComputedStyle(el, '::placeholder'); e.placeholderColor = pc.color; e.value = el.value || ''; }
    // exact box of the rendered glyphs (handles padding, flex centring, indents) and how many lines the browser used
    if (ownText) {
      const rg = document.createRange(); let L = 1e9, T = 1e9, R = -1e9, B = -1e9; const tops = new Set();
      for (const n of el.childNodes) if (n.nodeType === 3 && n.textContent.trim()) { rg.selectNodeContents(n); for (const q of rg.getClientRects()) { if (q.width < 0.5) continue; tops.add(Math.round(q.top)); L = Math.min(L, q.left); T = Math.min(T, q.top); R = Math.max(R, q.right); B = Math.max(B, q.bottom); } }
      if (R > L) { e.trect = { x: r1(L + scrollX), y: r1(T + scrollY), w: r1(R - L), h: r1(B - T) }; e.lines = tops.size; }
    }
    if (tag === 'input') e.pad = [cs.paddingTop, cs.paddingRight, cs.paddingBottom, cs.paddingLeft].map((v) => r1(parseFloat(v)));
    if (ownText || tag === 'input') {
      if (ownText) e.text = ownText.slice(0, 160);
      e.type = { family: cs.fontFamily.split(',')[0].replace(/["']/g, '').trim(), size: r1(parseFloat(cs.fontSize)), sizeU: r1(parseFloat(cs.fontSize) / U), weight: cs.fontWeight, style: cs.fontStyle, color: cs.color, letterSpacing: cs.letterSpacing, lineHeight: cs.lineHeight, align: cs.textAlign, transform: cs.textTransform !== 'none' ? cs.textTransform : undefined };
    }
    if (bg) e.bg = bg;
    if (bgImg) e.bgImage = bgImg;
    if (hasBorder) e.border = { width: cs.borderTopWidth + ' ' + cs.borderRightWidth + ' ' + cs.borderBottomWidth + ' ' + cs.borderLeftWidth, style: cs.borderTopStyle, color: cs.borderTopColor };
    if (cs.borderRadius !== '0px') e.radius = cs.borderRadius;
    if (shadow) e.shadow = shadow;
    if (cs.opacity !== '1') e.opacity = cs.opacity;
    if (tag === 'input') { e.placeholder = el.getAttribute('placeholder'); e.inputType = el.getAttribute('type'); }
    if (isIcon) { e.svg = el.outerHTML.replace(/\s+/g, ' ').slice(0, 1600); e.color = cs.color; }
    elements.push(e);
  }
  return { viewport: { w: W, h: innerHeight }, artboardUnit: r1((W / 735) * 1000) / 1000, title: document.title, scrollHeight: document.documentElement.scrollHeight, elements, art, images };
};

const CHROME = process.env.CHROME || [process.env.HOME + '/Library/Caches/ms-playwright/chromium_headless_shell-1248/chrome-headless-shell-mac-arm64/chrome-headless-shell'].find((p) => fs.existsSync(p));
const browser = await chromium.launch(CHROME ? { executablePath: CHROME } : {});
const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3 });
const page = await ctx.newPage();
for (const route of routes) {
  try {
    if (route === 'verify') {          // the OTP screen needs a started sign-in
      await page.goto(`${BASE}/#/signin`, { waitUntil: 'load' }); await page.reload({ waitUntil: 'load' }); await page.waitForTimeout(800);
      await page.fill('input[type=tel], input[inputmode=numeric], input', '9876543210');
      await page.getByRole('button', { name: /send otp/i }).click(); await page.waitForTimeout(1500);
    } else {
      await page.goto(`${BASE}/#/${route}`, { waitUntil: 'load' }); await page.reload({ waitUntil: 'load' });
      await page.waitForTimeout(route === 'reading' ? 900 : 1500);     // the reading screen auto-advances after ~4.4 s
    }
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({ path: path.join(OUT, `${route}.png`) });
    await page.screenshot({ path: path.join(OUT, `${route}_full.png`), fullPage: true });
    const spec = await page.evaluate(extract);
    spec.route = route; spec.shows = await page.evaluate(() => document.querySelector('.phone-preview')?.dataset.screen);
    fs.writeFileSync(path.join(OUT, `${route}.json`), JSON.stringify(spec, null, 1));
    console.log(route.padEnd(10), 'shows', String(spec.shows).padEnd(10), 'elements', String(spec.elements.length).padStart(4), 'art', spec.art.length, 'img', spec.images.length, 'scrollH', spec.scrollHeight);
  } catch (e) { console.log(route.padEnd(10), 'FAILED', String(e).slice(0, 120)); }
}
await browser.close();
