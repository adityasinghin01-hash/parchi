import { icons } from '../components/icons.js';
import { glyph, brand, primary, search, referenceArt, esc } from '../components/ui.js';
import { citiesFixture } from '../services/fixtures.js';

function areaRow(area,state,recent=false) {
  const selected=state.areaDraft?.id===area.id;
  return `<button type="button" class="area-row ${recent?'area-row--recent':''}" data-area-id="${esc(area.id)}" role="radio" aria-checked="${selected}"><span class="${recent?'recent-clock':'area-row__icon'}">${recent?glyph.clock:glyph[area.icon]||icons.location}</span><span><strong>${esc(area.label)}</strong>${area.detail?`<small>${esc(area.detail)}</small>`:''}</span><span class="area-radio ${selected?'selected':''}" aria-hidden="true"></span></button>`;
}
export function areaScreen(state) {
  const saved=state.areas?.saved||[];const recent=state.areas?.recent||[];
  return `<section class="screen area-screen" aria-labelledby="area-title">${brand({compact:true})}<h1 id="area-title">Choose your area</h1><p class="screen-description">We’ll show nearby medicine stores and labs<br>in this area.</p>
    ${search('area-search','Search area, locality or pincode',state.areaSearch)}
    <section class="map-placeholder" id="area-map" aria-label="Map unavailable" data-map-status="unavailable"><span class="map-placeholder__symbol">${glyph.map}</span><strong>Map unavailable</strong><p>You can still choose your area below.</p><button type="button" class="map-target" data-action="current-location" aria-label="Use current location">${glyph.target}</button></section>
    <button type="button" class="current-location-row" data-action="current-location"><span class="round-icon">${glyph.target}</span><span><strong>Use my current location</strong><small>${esc(state.locationStatus||'HSR Layout, Bengaluru 560102')}</small></span><span class="chevron">${icons.chevron}</span></button>
    <p class="form-error" id="area-error" role="status">${esc(state.error)}</p>
    <div id="area-search-results" class="area-search-results" ${state.areaSearch?'':'hidden'}></div>
    <section><div class="section-heading"><h2>Saved areas</h2><button type="button" data-action="manage-areas">Manage</button></div><div class="area-rows" role="radiogroup" aria-label="Saved areas">${saved.map(area=>areaRow(area,state)).join('')}</div></section>
    <section class="recent-areas"><div class="section-heading"><h2>Recent areas</h2><button type="button" data-action="clear-recent">Clear</button></div><div class="area-rows" role="radiogroup" aria-label="Recent areas">${recent.length?recent.map(area=>areaRow(area,state,true)).join(''):'<p class="muted-copy">No recent areas</p>'}</div></section>
    <section class="supported-cities"><div class="section-heading"><h2>Supported cities</h2><button type="button" data-action="more-cities">See all</button></div><div class="city-tiles">${citiesFixture.map(city=>`<button type="button" class="city-tile ${state.areaDraft?.city===city.label?'selected':''}" data-city="${city.id}" ${city.id==='more'?'':'aria-pressed="'+(state.areaDraft?.city===city.label)+'"'}>${city.crop?referenceArt('area',city.crop,'city-art'):glyph.grid}<strong>${city.label}</strong></button>`).join('')}</div></section>
    ${primary('Confirm this area','confirm-area',state.areaDraft?'':'disabled')}
  </section>`;
}
