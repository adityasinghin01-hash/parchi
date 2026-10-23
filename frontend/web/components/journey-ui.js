import {glyph,esc,referenceArt} from './ui.js';
import {icons} from './icons.js';
import {providerArt} from '../services/journey-fixtures.js';
import {money} from '../services/prescription.js';
const svg=body=>`<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${body}</svg>`;
export const jicon={...glyph,
 list:svg('<path d="M11 7h18M11 16h18M11 25h18M3 7h1M3 16h1M3 25h1"/>'),
 star:svg('<path d="m16 2 4 9 10 1-8 7 3 11-9-6-10 6 3-11-8-7 11-1Z"/>'),
 car:svg('<path d="m5 13 3-9h16l3 9M4 13h24v12H4ZM8 25v4m16-4v4M8 19h2m12 0h2"/>'),
 truck:svg('<path d="M2 6h18v19H2Zm18 7h6l4 6v6H20M23 14v5h7"/><circle cx="8" cy="26" r="3"/><circle cx="25" cy="26" r="3"/>'),
 external:svg('<path d="M18 3h11v11M29 3 14 18M12 6H4v23h23v-8"/>'),
 phone:svg('<path d="m5 2 7 6-4 5c3 6 5 8 11 10l5-4 6 7c-8 13-38-18-25-24Z"/>'),
 direction:svg('<path d="m2 12 28-10-10 28-5-13Z"/>'),
 download:svg('<path d="M16 2v20m-8-8 8 8 8-8M3 23v7h26v-7"/>'),
 share:svg('<path d="M16 21V2m-7 7 7-7 7 7M8 13H3v17h26V13h-5"/>'),
 info:svg('<circle cx="16" cy="16" r="13"/><path d="M16 14v10m0-16v1"/>'),
 bag:svg('<path d="M6 9h20l3 21H3Zm5 3V6a5 5 0 0 1 10 0v6"/>'),
 repeat:svg('<path d="M28 12A12 12 0 0 0 7 6L3 10m0-8v8h8M4 20a12 12 0 0 0 21 6l4-4m0 8v-8h-8"/>')
};
export const chevron=`<span class="j-chevron">${icons.chevron}</span>`;
export function providerLogo(id,cls=''){const art=providerArt[id];return `<span class="j-provider-logo ${cls}">${art?referenceArt(...art):glyph.box}</span>`;}
export function journeyHeader(title,description,{back='home',sans=false,location='HSR Layout',area=true,art=null,care=false}={}){
 return `<header class="j-header ${sans?'j-sans':''} ${care?'j-care-header':''}"><div class="j-topbar">${!care?`<button type="button" class="j-back" data-nav="${back}" aria-label="Go back">${glyph.back}</button>`:''}<div class="j-brand"><img src="assets/parchi-logo-transparent.png" alt=""><strong>Parchi</strong></div>${area?`<button type="button" class="j-area" data-journey="area">${icons.location}<span>${esc(location)}</span>${glyph.chevronDown}</button>`:''}</div><h1>${title}</h1><p>${description}</p>${art?referenceArt(...art,'j-heading-art'):''}</header>`;
}
export function journeyTabs(active){const current=active==='plans'?'history':active;return `<nav class="j-bottom-nav" aria-label="Main navigation">${[['home','Home',jicon.home],['history','Parchis',jicon.document],['track','Track',jicon.truck],['care','Care',jicon.heart],['account','Account',jicon.user]].map(([id,label,icon])=>`<button type="button" data-nav="${id}" ${current===id?'aria-current="page"':''}>${icon}<span>${label}</span></button>`).join('')}</nav>`;}
export const sampleNote=(text='Reference preview · prices, stock and times are not live')=>`<p class="j-sample-note">${text}</p>`;
export const actionButton=(label,action,extra='')=>`<button type="button" class="primary-action j-primary" data-journey="${action}" ${extra}>${label}${icons.arrow}</button>`;
export const statusPill=(label,tone='green',icon='checkCircle')=>`<span class="j-status ${tone}">${jicon[icon]||''}${esc(label)}</span>`;
export function priceBlock(plan){return `<div class="j-price"><strong>${money(plan.total)}</strong><span><s>${money(plan.referenceTotal)}</s><small>${plan.saving}% less</small></span></div>`;}
