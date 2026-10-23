import {glyph,esc} from './ui.js';
export function scanHeader(title,backTo){
  return `<header class="scan-header"><button type="button" class="scan-back" data-nav="${backTo}" aria-label="Go back">${glyph.back}</button><div class="scan-brand"><img src="assets/parchi-logo-transparent.png" alt=""><strong>Parchi</strong></div><h1>${esc(title)}</h1></header>`;
}
export const scanGlyph={
  warning:'<svg viewBox="0 0 32 30" aria-hidden="true"><path fill="currentColor" d="M13 3c1-3 5-3 6 0l13 23c1 2-1 4-3 4H3c-3 0-4-2-3-4Z"/><path d="M16 9v9m0 4v2" stroke="#fff" stroke-width="3" stroke-linecap="round"/></svg>',
  tablet:'<svg viewBox="0 0 40 40" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true"><ellipse cx="20" cy="20" rx="15" ry="11" transform="rotate(-35 20 20)"/><path d="M8 18c4 12 20 8 24-4M13 12l14 15"/></svg>',
  pen:'<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><path d="m4 24 2-7L22 2l5 5L11 22Zm3-7 4 5M18 6l5 5"/></svg>',
  flash:'<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m18 2-9 15h8l-2 13 9-17h-8ZM3 3l26 26"/></svg>'
};
