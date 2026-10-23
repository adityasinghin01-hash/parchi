import {esc,glyph,referenceArt} from '../components/ui.js';
import {icons} from '../components/icons.js';
import {scanHeader,scanGlyph} from '../components/scan-ui.js';

function confirmedRow(item,demo){
  const isTest=item.kind==='test',icon=isTest?glyph.flask:item.form==='Tablet'&&item.id==='amlodipine'?scanGlyph.tablet:glyph.pill;
  const badge=demo&&item.matchStatus==='exact'?'Exact match':demo&&item.badge?item.badge:item.userConfirmed?'Confirmed by you':'Check details';
  return `<button type="button" class="scan-confirmed-row" data-edit-item="${esc(item.id)}"><span class="scan-item-icon ${esc(item.iconTone||'rose')}">${icon}</span><span class="scan-item-copy"><strong>${esc(item.name)}</strong><span>${esc(item.form||item.detail||'Details not supplied')}</span>${item.schedule?`<small>${esc(item.schedule)}</small>`:''}</span><span class="scan-match-badge ${badge==='Check details'?'needs-check':''}">${glyph.checkCircle}${esc(badge)}</span><span class="scan-row-chevron">${icons.chevron}</span></button>`;
}
function uncertainRow(item){
  return `<article class="scan-uncertain-card ${item.unresolved?'':'is-resolved'}" id="uncertainty-${esc(item.id)}"><div class="uncertain-source">${item.sourceCrop?referenceArt('review-regenerated',item.sourceCrop):glyph.document}</div><div class="uncertain-copy"><h3>${item.reviewNumber}. ${esc(item.reviewTitle)}</h3><span class="uncertain-reason">${item.unresolved?scanGlyph.warning:glyph.checkCircle}${item.unresolved?esc(item.reviewReason):'Confirmed by you'}</span><div class="uncertain-choices" role="group" aria-label="Confirm ${esc(item.reviewTitle.toLowerCase())}">${item.candidates.map((candidate,index)=>`<button type="button" class="${item.choice===candidate||(!item.choice&&index===0)?'is-highlighted':''}" data-resolve-item="${esc(item.id)}" data-candidate="${esc(candidate)}" aria-pressed="${item.choice===candidate}">${esc(candidate)}</button>`).join('')}<button type="button" class="type-choice" data-type-item="${esc(item.id)}">${scanGlyph.pen}Type it</button></div>${item.choice&&!item.candidates.includes(item.choice)?`<p class="typed-choice">${esc(item.choice)}</p>`:''}</div></article>`;
}
export function reviewScreen(flow){
  const known=flow.items.filter(item=>!item.reviewTitle),meds=known.filter(item=>item.kind==='medicine'),tests=known.filter(item=>item.kind==='test'),uncertain=flow.items.filter(item=>item.reviewTitle);
  const pending=flow.items.filter(item=>item.unresolved).length,confirmed=flow.items.length-pending;
  return `<section class="screen scan-screen confirmation-screen">${scanHeader('Did we read it right?','capture')}
    <div class="scan-content"><div class="confirmation-summary" aria-live="polite"><div><span class="summary-check">${glyph.check}</span><span><strong>${confirmed} confirmed</strong><small>Looks good</small></span></div><div><span class="summary-warning">${scanGlyph.warning}</span><span><strong>${pending} need review</strong><small>Please verify</small></span></div></div>
    <section class="confirmation-section"><div class="confirmation-section-title"><h2>Medicines (${meds.length})</h2><span>${meds.length} ${flow.demo?'confirmed':'to verify'}</span></div><div class="confirmed-list">${meds.map(item=>confirmedRow(item,flow.demo)).join('')||'<p class="empty-flow">No medicines in this list.</p>'}</div></section>
    <section class="confirmation-section test-confirmation"><div class="confirmation-section-title"><h2>Tests (${tests.length})</h2><span>${tests.length} ${flow.demo?'confirmed':'to verify'}</span></div><div class="confirmed-list">${tests.map(item=>confirmedRow(item,flow.demo)).join('')||'<p class="empty-flow">No tests in this list.</p>'}</div></section>
    ${uncertain.length?`<section class="uncertainty-section"><div class="confirmation-section-title"><h2>${pending?'Needs your review':'Reviewed items'} (${pending||uncertain.length})</h2><span>${pending?'Please confirm or correct':'All reviewed'}</span></div><div class="uncertainty-list">${uncertain.map(uncertainRow).join('')}</div></section>`:''}
    <p class="confirmation-error" id="confirmation-error" role="alert">${esc(flow.reviewError||'')}</p><button type="button" class="primary-action all-correct" data-flow="confirm-review" ${flow.items.length?'':'disabled'}>All correct ${icons.arrow}</button><p class="scan-reference-note">${flow.demo?'Reference demo · sample prescription details':'Check every detail against your prescription'}</p></div>
  </section>`;
}
