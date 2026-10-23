import { icons } from './icons.js';

export const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const outline = body => `<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${body}</svg>`;
export const glyph = {
  pill: outline('<path d="M7 25a8 8 0 0 1 0-11L18 3a8 8 0 0 1 11 11L18 25a8 8 0 0 1-11 0ZM12 9l11 11"/>'),
  lock: '<svg viewBox="0 0 32 40" fill="currentColor" aria-hidden="true"><path d="M7 15V9a9 9 0 0 1 18 0v6h2a3 3 0 0 1 3 3v19H2V18a3 3 0 0 1 3-3Zm4 0h10V9a5 5 0 0 0-10 0Zm3 12v5h4v-5a3 3 0 1 0-4 0Z"/></svg>',
  check: outline('<path d="m5 16 7 7L27 8"/>'),
  checkCircle: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="11" fill="currentColor"/><path d="m6 12 4 4 8-9" fill="none" stroke="#fff" stroke-width="2"/></svg>',
  alert: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="11" fill="currentColor"/><path d="M12 5v9m0 3v2" stroke="#fff" stroke-width="2"/></svg>',
  bolt: '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M13 1 3 14h8l-1 9 11-15h-9Z"/></svg>',
  calendar: outline('<rect x="4" y="6" width="24" height="23" rx="3"/><path d="M10 3v7m12-7v7M4 13h24M10 18h4v5h-4Z"/>'),
  sliders: outline('<path d="M3 7h26M3 16h26M3 25h26"/><circle cx="11" cy="7" r="3" fill="#fff5e6"/><circle cx="22" cy="16" r="3" fill="#fff5e6"/><circle cx="9" cy="25" r="3" fill="#fff5e6"/>'),
  back: outline('<path d="m20 5-11 11 11 11"/>'),
  search: outline('<circle cx="13" cy="13" r="9"/><path d="m20 20 8 8"/>'),
  user: outline('<circle cx="16" cy="9" r="5"/><path d="M5 28v-4c0-10 22-10 22 0v4Z"/>'),
  userFill: '<svg viewBox="0 0 32 32" fill="currentColor" aria-hidden="true"><circle cx="16" cy="9" r="6"/><path d="M3 30v-3c0-14 26-14 26 0v3Z"/></svg>',
  photo: outline('<rect x="4" y="4" width="24" height="24" rx="4"/><circle cx="21" cy="11" r="2"/><path d="m5 23 8-9 8 8 3-3 4 4"/>'),
  whatsapp: '<svg viewBox="0 0 32 32" aria-hidden="true"><path d="M16 2a14 14 0 0 0-12 21L2 30l8-2a14 14 0 1 0 6-26Z" fill="none" stroke="currentColor" stroke-width="2"/><path d="M10 8c-4 1-2 7 1 10 3 3 9 6 11 2l-4-3-2 2c-3-1-4-3-5-5l2-2-3-4Z" fill="currentColor"/></svg>',
  home: outline('<path d="m3 14 13-11 13 11M7 13v16h7v-9h5v9h6V13"/>'),
  document: outline('<rect x="7" y="3" width="18" height="27" rx="3"/><path d="M12 9h8m-8 6h8m-8 6h5"/>'),
  box: outline('<path d="m3 9 13-6 13 6v15l-13 6-13-6Zm0 0 13 6 13-6M16 15v15M9 6l13 6"/>'),
  heart: outline('<path d="M16 28S2 18 2 10c0-9 12-10 14-2 3-8 14-7 14 2 0 8-14 18-14 18Z"/>'),
  flask: outline('<path d="M12 3h8m-7 0v12L5 28c-1 2 23 2 22 0l-8-13V3M9 22h14"/>'),
  clock: outline('<circle cx="16" cy="16" r="12"/><path d="M16 8v9l6 3"/>'),
  briefcase: outline('<rect x="3" y="9" width="26" height="20" rx="3"/><path d="M11 9V4h10v5M3 17h26m-16 0v4h6v-4"/>'),
  target: outline('<circle cx="16" cy="16" r="9"/><circle cx="16" cy="16" r="3"/><path d="M16 1v6m0 18v6M1 16h6m18 0h6"/>'),
  grid: outline('<rect x="4" y="4" width="9" height="9" rx="2"/><rect x="19" y="4" width="9" height="9" rx="2"/><rect x="4" y="19" width="9" height="9" rx="2"/><rect x="19" y="19" width="9" height="9" rx="2"/>'),
  keyboard: outline('<rect x="2" y="6" width="28" height="21" rx="3"/><path d="M7 11h1m4 0h1m4 0h1m4 0h1M7 16h1m4 0h1m4 0h1m4 0h1M8 22h16"/>'),
  bulb: outline('<path d="M10 22c0-5-5-6-5-12a11 11 0 0 1 22 0c0 6-5 7-5 12ZM11 26h10m-8 4h6"/>'),
  erase: outline('<path d="M11 5h18v22H11L2 16Zm4 6 9 10m0-10-9 10"/>'),
  map: outline('<path d="m3 7 9-4 9 4 8-4v23l-8 4-9-4-9 4ZM12 3v23M21 7v23"/>'),
  chevronDown: outline('<path d="m7 12 9 8 9-8"/>')
};

// Reuse only the illustration regions of the user's supplied artwork. Text,
// fields, buttons, navigation and cards are semantic HTML, not screenshot overlays.
let artSequence=0;
export function referenceArt(name, crop, cls = '', aspect = 'xMidYMid meet') {
  const [x,y,width,height] = crop;
  const sourceWidth = name==='plans-map'?1024:['home','lab-options','capture-camera','review-regenerated','plans-list','get-all-reference'].includes(name) ? 900 : 735;
  const clip=`reference-art-${++artSequence}`;
  return `<svg class="reference-art ${cls}" viewBox="${x} ${y} ${width} ${height}" preserveAspectRatio="${aspect}" aria-hidden="true" focusable="false"><defs><clipPath id="${clip}" clipPathUnits="userSpaceOnUse"><rect x="${x}" y="${y}" width="${width}" height="${height}"/></clipPath></defs><image clip-path="url(#${clip})" href="assets/references/${name}.jpeg" width="${sourceWidth}" height="${name==='plans-map'?1536:1600}"/></svg>`;
}

export function brand({compact = false, home = false} = {}) {
  if (home) return `<div class="home-brand"><img src="assets/parchi-logo-transparent.png" alt=""><div><span>Parchi</span><small>Medicines · Tests · Health, Simplified</small></div></div>`;
  return `<div class="reference-brand ${compact ? 'reference-brand--compact' : ''}"><img src="assets/parchi-logo-transparent.png" alt=""><div><strong>Parchi</strong><small>YOUR HEALTH,<br>MORE CLEARLY</small></div></div>`;
}
export const back = destination => `<button type="button" class="back-control" data-nav="${destination}" aria-label="Go back">${glyph.back}</button>`;
export const primary = (label, action, attrs = '') => `<button type="button" class="primary-action" data-action="${action}" ${attrs}>${label} ${icons.arrow}</button>`;
export const search = (id, placeholder, value = '') => `<label class="search-field"><span>${glyph.search}</span><input id="${id}" type="search" autocomplete="off" placeholder="${placeholder}" aria-label="${placeholder}" value="${esc(value)}"></label>`;
export const divider = '<div class="or-divider"><span>OR</span></div>';
export function tabs(active = 'home') {
  return `<nav class="bottom-tabs" aria-label="Main navigation">${[['home','Home',glyph.home],['parchis','Parchis',glyph.document],['track','Track',glyph.box],['care','Care',glyph.heart],['account','Account',glyph.user]].map(([id,label,icon]) => `<button type="button" data-tab="${id}" ${id === active ? 'aria-current="page"' : ''}>${icon}<span>${label}</span>${id === active ? '<i></i>' : ''}</button>`).join('')}</nav>`;
}
