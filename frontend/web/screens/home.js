import { icons } from '../components/icons.js';
import { glyph, brand, primary, tabs, search, referenceArt, esc } from '../components/ui.js';

export function recentRow(item) {
  return `<button type="button" class="recent-row" data-recent="${esc(item.id)}"><span class="recent-row__icon ${item.icon==='flask'?'green':'rose'}">${item.icon==='flask'?glyph.flask:'<span class="rx-symbol">℞</span>'}</span><span class="recent-row__copy"><strong>${esc(item.name)}</strong><small>${esc(item.summary)}</small></span><time>${esc(item.date)}</time><span class="status-pill ${esc(item.tone)}">${esc(item.status)}</span><span class="chevron">${icons.chevron}</span></button>`;
}
export function homeScreen(state) {
  const data=state.home;
  if(!data)return `<section class="screen home-screen"><div class="skeleton skeleton-header"></div><div class="skeleton skeleton-hero"></div><p class="loading-copy">Loading your home…</p>${state.error?`<p class="form-error">${esc(state.error)}</p><button class="primary-action" data-action="retry-home">Retry</button>`:''}${tabs()}</section>`;
  const order=data.activeOrder;
  return `<section class="screen home-screen" aria-label="Parchi home"><header class="home-header">${brand({home:true})}<button type="button" class="account-bubble" data-nav="account" aria-label="Account">${glyph.user}</button></header>
    <button class="home-location" type="button" data-nav="area"><span class="home-location__pill">${icons.location}<strong>${esc(state.area?.city||state.area?.label||data.area)}</strong>${glyph.chevronDown}</span><small><i></i>${esc(data.serviceLabel)}</small></button>
    ${search('home-search','Search parchis, medicines, tests or shops',state.homeSearch)}
    <div class="scan-hero"><div class="scan-hero__copy"><h1>Scan or<br>share parchi</h1><p>Get medicines and tests<br>delivered from trusted<br>nearby stores and labs.</p></div>${referenceArt('home',[465,391,337,277],'scan-hero__art')}
      <div class="scan-hero__actions"><button type="button" data-nav="capture"><span class="scan-icon camera">${icons.camera}</span><small>Scan<br>Parchi</small></button><button type="button" data-action="pick-photos"><span class="scan-icon photo">${glyph.photo}</span><small>Choose<br>from Photos</small></button><button type="button" data-action="whatsapp-import"><span class="scan-icon whatsapp">${glyph.whatsapp}</span><small>Share from<br>WhatsApp</small></button>${primary('Start now','start-capture')}</div>
    </div>
    ${order?`<section class="active-order"><div class="order-top"><span class="round-icon order-box">${glyph.box}</span><div><p>1 active order</p><h2>Arriving in ${esc(order.etaMinutes)} min</h2><small>${esc(order.seller)} · ${esc(order.itemCount)} items</small></div><button type="button" class="icon-button" data-tab="track" aria-label="View active order">${icons.chevron}</button>${referenceArt('home',[550,860,242,91],'courier-art')}</div><div class="order-bottom"><div class="order-timeline"><span class="done">Preparing</span><span class="current">Out for delivery</span><span>Arriving</span></div><button type="button" class="track-button" data-tab="track">Track ${icons.chevron}</button></div></section>`:''}
    <section class="recent-section"><div class="section-heading"><h2>Recent parchis</h2><button type="button" data-tab="parchis">See all ${icons.chevron}</button></div><div id="recent-rows">${data.recent.map(recentRow).join('')}</div></section>
    <button type="button" class="how-card" data-info="how"><span class="round-icon">${glyph.bulb}</span><span><strong>How Parchi works</strong><small>From upload to delivery, in a few simple steps</small></span><span class="chevron">${icons.chevron}</span></button>
    ${data.source==='reference-demo'?'<p class="reference-data-label">Sample data from your design reference</p>':''}${tabs()}
  </section>`;
}
