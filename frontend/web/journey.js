import {esc,glyph} from './components/ui.js';
import {plansFixture,checkoutFixture,trackingFixture,careFixture,passFixture,planReviewFixture} from './services/journey-fixtures.js';
import {money} from './services/prescription.js';
import {plansScreen} from './screens/plans.js';
import {getAllScreen} from './screens/get-all.js';
import {checkoutScreen} from './screens/checkout.js';
import {trackingScreen} from './screens/tracking.js';
import {careScreen} from './screens/care.js';
import {passScreen} from './screens/pass.js';
export const journeyRoutes=['plans','plan-map','get-all','checkout','track','care','pass'];
const clone=value=>structuredClone(value);
export function createJourney({state,navigate,render,showDialog,closeDialog,toast,mapProvider}){
 const model={mode:'reference',plans:clone(plansFixture),visiblePlans:[],selectedPlan:'plan-1',sort:'cheapest',expandedPlans:[],slot:null,hideSignin:false,
 checkout:clone(checkoutFixture),checkoutOpen:'apollo',checkoutStatus:{},checkoutSelection:{},checkoutSearch:'',estimateOpen:null,checkoutStep:0,
 tracking:clone(trackingFixture),trackingExpanded:[],collapsedTracking:[],care:clone(careFixture),careTab:'medicines',autoRefill:false,reminders:{medicine:true,tests:true},pass:clone(passFixture),loading:false,error:'',requirements:null};
 let mapCleanup=null,request=null,version=0,lastRoute=null,loaded=false;
 function sortPlans(){model.visiblePlans=[...model.plans].filter(plan=>model.sort!=='no-trips'||plan.trips===0);model.visiblePlans.sort((a,b)=>model.sort==='best'?a.bestRank-b.bestRank:model.sort==='fastest'?a.readyRank-b.readyRank:(a.total??Infinity)-(b.total??Infinity));}
 sortPlans();
 function requirements(detail){model.historicalPass=false;request?.abort();version++;loaded=false;model.requirements=clone(detail.items);model.mode='requirements';model.plans=[];model.visiblePlans=[];model.error='';model.selectedPlan=null;}
 function prepare(route){mapCleanup?.();mapCleanup=null;if(route!==lastRoute){request?.abort();version++;model.loading=false;lastRoute=route;}}
 async function loadPlans(){
  if(model.mode!=='requirements'||loaded||model.loading)return;
  loaded=true;const service=window.PARCHI_JOURNEY_SERVICE;
  if(!service?.loadPlans)return;
  const current=++version;request=new AbortController();model.loading=true;render({keepScroll:true});
  try{const data=await service.loadPlans({items:clone(model.requirements),area:state.area,signal:request.signal});if(current!==version)return;
   if(!Array.isArray(data.plans)||data.plans.some(plan=>!plan.id||!Number.isInteger(plan.total)||plan.total<0))throw new Error('The complete-plan response could not be read.');
   model.plans=data.plans;model.mode='live';model.liveData=data;model.selectedPlan=data.plans[0]?.id||null;sortPlans();
  }catch(error){if(current!==version||error.name==='AbortError')return;model.error=error.message||'Complete plans could not be loaded.';}
  model.loading=false;render({keepScroll:true});
 }
 function mounted(route){
  if(['plans','plan-map'].includes(route)){loadPlans();if(route==='plan-map'&&model.mode!=='requirements'){
   const element=document.querySelector('#journey-map');if(!element)return;
   try{mapCleanup=mapProvider.mount(element,{area:state.area,onSelect:value=>{if(value.planId&&model.plans.some(plan=>plan.id===value.planId)){model.selectedPlan=value.planId;render({keepScroll:true});}},onStatus:status=>{element.dataset.mapStatus=status.state;const title=element.querySelector('strong');if(title)title.textContent=status.message||(status.state==='ready'?'Nearby providers':'Map unavailable');}});}catch{element.dataset.mapStatus='error';}
  }}
 }
 function resetSample(){model.mode='reference';model.plans=clone(plansFixture);model.selectedPlan='plan-1';model.sort='cheapest';model.error='';model.requirements=null;model.checkout=clone(checkoutFixture);sortPlans();render({keepScroll:true});}
 function selectedPlan(){return model.plans.find(plan=>plan.id===model.selectedPlan);}
 function reviewSelected(){if(!selectedPlan())return;model.checkout=model.mode==='reference'&&selectedPlan().number===1?clone(checkoutFixture):model.liveData?.checkoutByPlan?.[model.selectedPlan]||[];navigate('get-all');}
 function dialogInfo(title,text){showDialog(title,`<p>${esc(text)}</p><button type="button" class="primary-action" data-close>Done</button>`);}
 function slotDialog(){showDialog('Choose a collection slot',`<p>Choose a preferred slot for this preview. It will need confirmation from the lab.</p><form id="journey-slot"><label for="slot-choice">Preferred slot</label><select class="dialog-field" id="slot-choice"><option>Today · 4:30 PM – 5:00 PM</option><option>Today · 6:00 PM – 6:30 PM</option><option>Tomorrow · 9:00 AM – 9:30 AM</option></select><button type="submit" class="primary-action">Save preference</button></form>`);}
 function seller(id){return model.checkout.find(item=>item.id===id);}
 function advanceCheckout(){const next=model.checkout.find(item=>!model.checkoutStatus[item.id]);if(next){model.checkoutOpen=next.id;model.checkoutStep=next.kind==='Lab'?1:0;}else model.checkoutStep=2;model.checkoutSearch='';render();}
 async function openStore(id){
  const item=seller(id);if(!item)return;
  if(!window.PARCHI_CHECKOUT_PROVIDER?.prepare){dialogInfo('Seller checkout is not connected',`The ${item.name} cart and checkout link are not connected in this preview. No items have been added to a seller website and no payment has been made.`);return;}
  try{const chosen=model.checkoutSelection[id]||item.items.map(entry=>entry.id);const response=await window.PARCHI_CHECKOUT_PROVIDER.prepare({sellerId:id,itemIds:chosen});const url=new URL(response.url);if(url.protocol!=='https:')throw new Error('A secure checkout link is required.');showDialog('Continue to the seller',`<p>Review the exact items and final price in ${esc(item.name)}. A handoff does not verify payment or order acceptance.</p><a class="dialog-secondary" href="${esc(url.href)}" target="_blank" rel="noopener noreferrer">Open ${esc(item.name)}</a>`);}catch(error){dialogInfo('Checkout unavailable',error.message||'Please try again later.');}
 }
 async function click(button){
  if(button.dataset.planView){navigate(button.dataset.planView==='map'?'plan-map':'plans');return true;}
  if(button.dataset.planSort){model.sort=button.dataset.planSort;sortPlans();render({keepScroll:true});document.querySelector(`[data-plan-sort="${model.sort}"]`)?.focus({preventScroll:true});return true;}
  if(button.dataset.selectPlan){model.selectedPlan=button.dataset.selectPlan;render({keepScroll:true});return true;}
  if(button.dataset.planExpand){const id=button.dataset.planExpand;model.expandedPlans=model.expandedPlans.includes(id)?model.expandedPlans.filter(value=>value!==id):[...model.expandedPlans,id];render({keepScroll:true});return true;}
  if(button.dataset.reviewSeller){const entry=planReviewFixture.find(item=>item.id===button.dataset.reviewSeller);if(entry)dialogInfo(entry.name,`${entry.summary}. Reference seller amount: ${money(entry.total)}. The screenshot allocates 7 of the 8 claimed medicines and leaves ₹50 of the total unitemized. Final items and fees need confirmation.`);else dialogInfo('Item allocation pending','The reference does not supply this seller’s exact item allocation.');return true;}
  if(button.dataset.checkoutOpen){model.checkoutOpen=button.dataset.checkoutOpen;model.checkoutSearch='';render({keepScroll:true});return true;}
  if(button.dataset.checkoutEstimate){model.estimateOpen=model.estimateOpen===button.dataset.checkoutEstimate?null:button.dataset.checkoutEstimate;render({keepScroll:true});return true;}
  if(button.dataset.checkoutContact){const entry=seller(button.dataset.checkoutContact);dialogInfo(button.dataset.contact==='call'?'Seller contact':'Directions unavailable',`${entry.name} ${button.dataset.contact==='call'?'phone details':'map directions'} are not connected. No call or location request has been made.`);return true;}
  if(button.dataset.checkoutExternal){await openStore(button.dataset.checkoutExternal);return true;}
  if(button.dataset.checkoutSkip){const entry=seller(button.dataset.checkoutSkip);showDialog('Skip this seller?',`<p>Items from ${esc(entry.name)} will remain unconfirmed. Your plan will not be complete.</p><button type="button" class="primary-action" data-checkout-skip-confirm="${entry.id}">Skip for this preview</button>`);return true;}
  if(button.dataset.checkoutSkipConfirm){model.checkoutStatus[button.dataset.checkoutSkipConfirm]='skipped';closeDialog();advanceCheckout();return true;}
  if(button.dataset.checkoutOrdered){const entry=seller(button.dataset.checkoutOrdered);showDialog('Confirm your order update',`<p>Only mark this after completing the seller’s checkout. This is a self-reported update, not payment verification.</p><form id="journey-order" data-seller="${entry.id}"><label for="seller-order-reference">Seller order reference (optional)</label><input id="seller-order-reference" class="dialog-field" maxlength="100"><label class="preference-option"><span>I completed this order on the seller’s app or website</span><input name="completed" type="checkbox" required></label><button type="submit" class="primary-action">Confirm for this preview</button></form>`);return true;}
  if(button.dataset.trackingItems){const id=button.dataset.trackingItems;model.trackingExpanded=model.trackingExpanded.includes(id)?model.trackingExpanded.filter(value=>value!==id):[...model.trackingExpanded,id];render({keepScroll:true});return true;}
  if(button.dataset.trackingGroup){const id=button.dataset.trackingGroup;model.collapsedTracking=model.collapsedTracking.includes(id)?model.collapsedTracking.filter(value=>value!==id):[...model.collapsedTracking,id];render({keepScroll:true});return true;}
  if(button.dataset.trackingDetails){const entry=model.tracking.find(item=>item.id===button.dataset.trackingDetails);showDialog(esc(entry.name),`<p>${esc(entry.status)} · HSR Layout<br>${entry.steps.map(step=>`${esc(step[0])}: ${esc(step[1])}`).join('<br>')}</p><p class="preview-note">Sample tracking record. No live order or booking is connected.</p>${entry.kind==='test'?'<button type="button" class="primary-action" data-journey="slot">Choose a preferred slot</button>':'<button type="button" class="primary-action" data-journey="help">Get help</button>'}`);return true;}
  if(button.dataset.careTab){model.careTab=button.dataset.careTab;render({keepScroll:true});document.querySelector(`[data-care-tab="${model.careTab}"]`)?.focus({preventScroll:true});return true;}
  if(button.dataset.careDose){const item=model.care.find(entry=>entry.id===button.dataset.careDose);showDialog(esc(item.name),`<p>${esc(item.detail)}<br>${esc(item.time)} · ${esc(item.status)}</p><p class="preview-note">Schedule copied from the sample reference. Record only what you actually took; this preview does not give dosing advice.</p><button type="button" class="primary-action" data-dose-update="${item.id}">${item.status==='Taken'?'Undo taken status':'Mark as taken'}</button>`);return true;}
  if(button.dataset.doseUpdate){const item=model.care.find(entry=>entry.id===button.dataset.doseUpdate);item.status=item.status==='Taken'?'Due':'Taken';closeDialog();render({keepScroll:true});return true;}
  const action=button.dataset.journey;if(!action)return false;
  if(action==='sample-plans')resetSample();
  if(action==='review-selected')reviewSelected();
  if(action==='start-checkout'){if(!model.checkout.length){dialogInfo('Checkout allocation pending','The selected plan needs exact seller items and checkout links before continuing.');return true;}navigate('checkout');}
  if(action==='area'){state.areaReturn=state.route;navigate('area');}
  if(action==='hide-signin'){model.hideSignin=true;render({keepScroll:true});}
  if(action==='slot')slotDialog();
  if(action==='ranking')dialogInfo('How we rank','Compare complete item coverage, total cost including known fees, readiness and trips. The source comparison prices and best-fit labels in these reference samples are not verified rankings. Missing fees stay unknown.');
  if(action==='map-location'||action==='directions')dialogInfo('Map unavailable','Live maps and directions are not connected. No device location has been requested.');
  if(action==='help')showDialog('How can we help?',`<p>Choose the next step. No seller or support message is sent from this preview.</p><button type="button" class="dialog-secondary" data-journey="contact-seller">Contact a seller</button><button type="button" class="dialog-secondary" data-journey="slot">Reschedule a lab test</button><button type="button" class="dialog-secondary" data-journey="report-issue">Report an issue</button><button type="button" class="dialog-secondary" data-nav="pass">Open Parchi Pass</button>`);
  if(action==='contact-seller')dialogInfo('Seller contacts unavailable','Verified seller phone numbers and support channels have not been connected.');
  if(action==='report-issue')showDialog('Report an issue',`<form id="journey-issue"><label for="issue-description">Describe the issue</label><textarea class="dialog-field" id="issue-description" maxlength="1000" required></textarea><p class="preview-note">Saved locally in this page only. Nothing is sent to a seller or support team.</p><button type="submit" class="primary-action">Save issue preview</button></form>`);
  if(action==='schedule')showDialog('Full sample schedule',`<p>${model.care.map(item=>`${esc(item.time)} · ${esc(item.name)}<br>${esc(item.detail)}`).join('<br><br>')}</p><p class="preview-note">Reference schedule only. No doses are calculated from OCR.</p><button class="primary-action" type="button" data-close>Done</button>`);
  if(['all-tests','test-details'].includes(action))showDialog('Sample lab test details',`<p>Complete Blood Count (CBC)<br>Thyrocare Diagnostics · HSR Layout<br>Today, 4:30 PM<br>CBC (24 parameters)</p><p class="preview-note">The reference says “No fasting required.” Actual preparation must be supplied by the lab; this is not a general instruction.</p><button type="button" class="primary-action" data-journey="slot">Choose a preferred slot</button>`);
  if(action==='refills')dialogInfo('Refill preview','Pantoprazole 40 mg · 10 tablets left · refill due in 5 days. These are sample values; no quantity is inferred from medicine intake.');
  if(action==='enable-refill'){model.autoRefill=true;closeDialog();render({keepScroll:true});toast('Preview preference saved. No automatic purchase or refill is scheduled.');}
  if(action==='reminders')showDialog('Manage reminders',`<form id="journey-reminders"><label class="preference-option"><span>Medicine reminders</span><input type="checkbox" name="medicine" ${model.reminders.medicine?'checked':''}></label><label class="preference-option"><span>Lab test reminders</span><input type="checkbox" name="tests" ${model.reminders.tests?'checked':''}></label><p class="preview-note">Preferences only. Browser or native notifications are not scheduled.</p><button type="submit" class="primary-action">Save preferences</button></form>`);
  if(action==='save-pass')await downloadPass();
  if(action==='share-pass')await sharePass();
  if(action==='copy-pass'){try{await navigator.clipboard.writeText(passText());toast('Demo pass text copied.');}catch{toast('Select and copy the pass text below.');}}
  return true;
 }
 function change(input){
  if(input.dataset.checkoutItem){const entry=seller(input.dataset.seller);const chosen=model.checkoutSelection[entry.id]||entry.items.map(item=>item.id);model.checkoutSelection[entry.id]=input.checked?[...new Set([...chosen,input.dataset.checkoutItem])]:chosen.filter(id=>id!==input.dataset.checkoutItem);render({keepScroll:true});return true;}
  if(input.id==='auto-refill'){if(input.checked){input.checked=model.autoRefill;showDialog('Auto-refill preference',`<p>This saves a preview preference only. It does not order medicine, charge money or schedule a refill.</p><button type="button" class="primary-action" data-journey="enable-refill">Enable preview preference</button>`);}else{model.autoRefill=false;}return true;}
  return false;
 }
 function input(target){if(target.id!=='checkout-search')return;model.checkoutSearch=target.value;document.querySelectorAll('[data-checkout-name]').forEach(row=>row.hidden=!row.dataset.checkoutName.includes(target.value.toLowerCase()));}
 function submit(form){
  if(form.id==='journey-slot'){model.slot=form.querySelector('#slot-choice').value;closeDialog();render({keepScroll:true});toast('Slot preference saved in this preview; not booked.');return true;}
  if(form.id==='journey-order'){if(!form.querySelector('[name=completed]').checked)return true;model.checkoutStatus[form.dataset.seller]='ordered';model.orderReferences??={};model.orderReferences[form.dataset.seller]=form.querySelector('#seller-order-reference').value.trim();closeDialog();advanceCheckout();return true;}
  if(form.id==='journey-issue'){model.issue=form.querySelector('#issue-description').value.trim();closeDialog();toast('Issue saved in this page only. Nothing was sent.');return true;}
  if(form.id==='journey-reminders'){const data=new FormData(form);model.reminders={medicine:data.has('medicine'),tests:data.has('tests')};closeDialog();toast('Preview preferences saved. Notifications are not scheduled.');return true;}
  return false;
 }
 function passText(){const pass=model.pass;return `Parchi Pass · DEMO\n${pass.id}\n${pass.patient}\n${pass.date}\n${pass.area}\nPatient confirmed sample list\n\nMedicines\n${pass.medicines.map(item=>`${item.name} · ${item.form} · ${item.quantity}`).join('\n')}\n\nLab tests\n${pass.tests.map(item=>`${item.name} · ${item.quantity}`).join('\n')}\n\nDemo only; not a verified medical record. Prices and availability may vary.`;}
 async function offlinePass(){const pass=model.pass;const qr=await fetch('assets/parchi-pass-demo-qr.svg').then(response=>{if(!response.ok)throw new Error('The offline QR asset is unavailable.');return response.text();});return `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Parchi Pass ${esc(pass.id)}</title><style>body{margin:0;padding:24px;background:#fffbf2;color:#421c08;font:16px system-ui,sans-serif}main{max-width:650px;margin:auto}h1{font:700 36px Georgia}img{width:210px;max-width:90%;display:block;margin:18px 0}pre{font:inherit;line-height:1.6;white-space:pre-wrap}footer{border-top:1px solid #dcc9b0;padding-top:16px;color:#786b59} @media print{body{background:white;padding:0}}</style><main><h1>Parchi Pass</h1><p>Patient confirmed sample list · ${esc(pass.id)}</p><img alt="Demo pass QR code" src="data:image/svg+xml;charset=utf-8,${encodeURIComponent(qr)}"><pre>${esc(passText())}</pre><footer>Saved for offline viewing. DEMO · partner acceptance and medical validity are not established.</footer></main></html>`;}
 async function downloadPass(){try{const html=await offlinePass();const url=URL.createObjectURL(new Blob([html],{type:'text/html;charset=utf-8'}));const link=document.createElement('a');link.href=url;link.download='Parchi-Pass-DEMO.html';document.body.append(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);toast('Offline demo pass downloaded.');}catch(error){dialogInfo('Save unavailable',error.message);}}
 async function sharePass(){if(navigator.share){try{await navigator.share({title:'Parchi Pass · DEMO',text:passText()});return;}catch(error){if(error.name==='AbortError')return;}}showDialog('Share demo pass',`<p>Share this sample only with someone you choose. Nothing has been sent.</p><textarea class="dialog-field" rows="10" readonly aria-label="Demo pass text">${esc(passText())}</textarea><button type="button" class="primary-action" data-journey="copy-pass">Copy pass text</button><button type="button" class="dialog-secondary" data-journey="save-pass">Save offline pass</button>`);}
 function screen(route){
  if(['plans','plan-map'].includes(route))return plansScreen(model,state.area,route==='plan-map');
  if(model.mode!=='reference'&&['get-all','checkout','pass'].includes(route)&&!(route==='pass'&&model.historicalPass))return plansScreen(model,state.area,false);
  if(route==='get-all')return getAllScreen(model,state.area);
  if(route==='checkout')return checkoutScreen(model,state.area);
  if(route==='track')return trackingScreen(model,state.area);
  if(route==='care')return careScreen(model,state.area);
  return passScreen(model,state.area);
 }
 return {openReferencePass(back){model.historicalPass=true;model.passReturn=back;model.pass=clone(passFixture);},resetSession(){request?.abort();version++;loaded=false;Object.assign(model,{mode:'reference',plans:clone(plansFixture),selectedPlan:'plan-1',sort:'cheapest',expandedPlans:[],slot:null,hideSignin:false,checkout:clone(checkoutFixture),checkoutOpen:'apollo',checkoutStatus:{},checkoutSelection:{},checkoutSearch:'',estimateOpen:null,checkoutStep:0,tracking:clone(trackingFixture),trackingExpanded:[],collapsedTracking:[],care:clone(careFixture),careTab:'medicines',autoRefill:false,reminders:{medicine:false,tests:false},pass:clone(passFixture),historicalPass:false,passReturn:'get-all',requirements:null,issue:null,orderReferences:{},loading:false,error:''});sortPlans();},requirements,prepare,mounted,click,change,input,submit,screen,dialogClosed(){}};
}
