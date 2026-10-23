import {glyph,esc} from '../components/ui.js';
import {money} from '../services/prescription.js';
import {planReviewFixture} from '../services/journey-fixtures.js';
import {journeyHeader,providerLogo,jicon,actionButton,sampleNote,chevron} from '../components/journey-ui.js';
export function getAllScreen(model,area){
 const plan=model.plans.find(plan=>plan.id===model.selectedPlan)||model.plans[0];
 const sellers=plan.number===1?planReviewFixture:plan.providers.map((id,index)=>({id,name:{apollo:'Apollo Pharmacy',lal:'Dr. Lal PathLabs',netmeds:'Netmeds',pharmeasy:'PharmEasy',tata:'Tata 1mg',srl:'SRL Diagnostics'}[id],kind:index===plan.providers.length-1?'test':'medicine',total:null,count:null,summary:'Item allocation and seller quote await confirmation',method:'Fulfilment not confirmed'}));
 return `<section class="screen journey-screen get-all-screen">${journeyHeader('Get it all review','Check everything before checkout.',{back:'plans',sans:true,area:false})}<div class="getall-summary"><div><span>Total payable</span><strong>${money(plan.total)}</strong><small><b>${plan.saving}% less</b><s>${money(plan.referenceTotal)}</s></small></div><div><span>Ready by</span><p>${jicon.clock}<strong>${esc(plan.ready)}</strong></p></div><div><span>Total trips</span><p>${jicon.car}<strong>${plan.trips} trips</strong></p></div></div>
 <div class="getall-address">${jicon.target}<span>Deliver to: <strong>${esc(area?.detail||area?.label||'Sector 62, Noida')}</strong></span><button type="button" data-journey="area">Change ${chevron}</button></div>
 <div class="getall-sellers">${sellers.map(seller=>`<button type="button" class="getall-seller" data-review-seller="${seller.id}">${providerLogo(seller.id)}<span class="getall-seller-copy"><span class="getall-seller-title"><strong>${esc(seller.name)}</strong><small>${seller.kind==='test'?'Lab tests':'Medicines'} (${seller.count??'—'})</small><b>${money(seller.total)}</b>${chevron}</span><span class="getall-seller-items">${esc(seller.summary)}</span><span class="getall-fulfilment"><span>${seller.method==='Store pickup'?jicon.car:jicon.home}${esc(seller.method)}</span>${seller.time?`<small><i></i>Sample price · ${seller.time}</small>`:''}</span></span></button>`).join('')}</div>
 <div class="j-row slot-row"><i>${jicon.clock}</i><span><strong>Home collection</strong><small>${esc(model.slot||'Today · 4:30 PM – 5:00 PM')}</small></span><button type="button" data-journey="slot">Change slot ${chevron}</button></div>
 <div class="j-notice">${glyph.document}<span><strong>You will complete payment in each seller’s app or website.</strong><small>Parchi will guide the process.</small></span></div>
 <button type="button" class="j-row" data-journey="ranking"><i>${jicon.list}</i><span><strong>How we rank</strong><small>We compare total cost, delivery time and seller ratings.</small></span>${chevron}</button>
 ${!model.hideSignin?`<div class="j-row"><i>${glyph.user}</i><button type="button" class="j-row-signin" data-nav="signin"><strong>Sign in to save this plan across devices</strong><small>Keep your medicines and tests for later.</small></button><button type="button" data-journey="hide-signin">Not now</button></div>`:''}
 ${actionButton('<span>Get it all<small>Checkout assistant starts next</small></span>','start-checkout')}${sampleNote('Reference preview · final fees and item allocation need confirmation')}
 </section>`;
}
