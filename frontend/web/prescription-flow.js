import {sampleReviewItems} from './services/review-fixtures.js';
import {esc,glyph,referenceArt} from './components/ui.js';
import {sampleItems,selectedItems,referenceOffers,money,prescriptionService} from './services/prescription.js';
import {readingScreen,prescriptionImage} from './screens/reading.js';
import {reviewScreen} from './screens/review.js';
import {compareScreen} from './screens/compare.js';

export const prescriptionRoutes=['reading','review','medicines','labs'];
export function createPrescriptionFlow({state,navigate,render,showDialog,closeDialog,toast,mapProvider}){
  let lastRoute=null,readTimer=null,readRequest=null,quoteRequest=null,readVersion=0,quoteVersion=0,mapCleanup=null,focusSelector=null;
  const fresh=()=>({items:sampleReviewItems(),demo:true,reviewError:'',source:'sample',stage:1,error:'',imageUrl:null,reviewTab:'medicine',kind:'medicine',offers:{},quoteLoaded:{},selected:{medicine:'apollo',test:'thyrocare'},sort:'reference',onlyComplete:false,homeOnly:false,loading:false,quoteError:'',visibleOffers:[],running:false});
  let flow=fresh();
  const stopReading=()=>{clearTimeout(readTimer);readTimer=null;readRequest?.abort();readRequest=null;readVersion++;flow.running=false;};
  function visible(){
    const complete=offer=>Number.isInteger(offer.availableCount)&&offer.availableCount>0&&offer.availableCount===offer.requiredCount;
    const list=[...(flow.offers[flow.kind]||[])].filter(offer=>(!flow.onlyComplete||complete(offer))&&(!flow.homeOnly||offer.badges.some(([icon])=>icon==='home')));
    // Complete and partial baskets are separate; never rank a partial total as
    // cheaper than a complete prescription. Null quotes sort after known prices.
    if(flow.sort!=='reference')list.sort((a,b)=>Number(complete(b))-Number(complete(a))||
      (flow.sort==='price'?(a.pricePaise??Infinity)-(b.pricePaise??Infinity):flow.sort==='fastest'?(a.readyMinutes??Infinity)-(b.readyMinutes??Infinity):a.distance-b.distance));
    flow.visibleOffers=list;
  }
  function prepare(route){
    if(route!==lastRoute){
      const initialRoute=lastRoute===null;
      if(lastRoute==='reading')stopReading();
      if(['medicines','labs'].includes(lastRoute)){quoteRequest?.abort();quoteVersion++;flow.loading=false;}
      lastRoute=route;
      if(route==='reading'){flow.stage=1;flow.error='';flow.running=false;}
      if(route==='medicines'||route==='labs'){
        if(initialRoute&&flow.demo)flow.items=sampleItems();
        flow.kind=route==='labs'?'test':'medicine';flow.sort='reference';flow.onlyComplete=false;flow.homeOnly=false;
        if(flow.demo){flow.offers[flow.kind]=referenceOffers(flow.items,flow.kind);visible();}
        else{flow.offers[flow.kind]=[];flow.quoteLoaded[flow.kind]=false;flow.visibleOffers=[];flow.quoteError='';}
      }
    }
  }
  async function quotes(){
    const kind=flow.kind,version=++quoteVersion;quoteRequest?.abort();quoteRequest=new AbortController();
    flow.quoteError='';
    if(flow.demo){flow.offers[kind]=referenceOffers(flow.items,kind);visible();render({keepScroll:true});return;}
    if(!prescriptionService?.compare){flow.quoteError='Live provider quotes are not connected yet.';visible();render({keepScroll:true});return;}
    flow.loading=true;render({keepScroll:true});
    try{
      const offers=await prescriptionService.compare({items:selectedItems(flow.items),kind,area:state.area,signal:quoteRequest.signal});
      if(version!==quoteVersion)return;
      if(!Array.isArray(offers))throw new Error('The provider response could not be read.');
      flow.offers[kind]=offers.map(offer=>({...offer,badges:offer.badges||[]}));
      flow.quoteLoaded[kind]=true;
      flow.selected[kind]=flow.offers[kind].find(offer=>Number.isInteger(offer.availableCount)&&offer.availableCount>0&&offer.availableCount===offer.requiredCount)?.id||offers[0]?.id;
      visible();
    }catch(error){if(version!==quoteVersion||error.name==='AbortError')return;flow.quoteError=error.message||'Could not load provider quotes.';}
    flow.loading=false;render({keepScroll:true});
  }
  function mounted(route){
    if(focusSelector){document.querySelector(focusSelector)?.focus({preventScroll:true});focusSelector=null;}
    if(route==='reading'&&!flow.running&&!flow.error)read();
    if(['medicines','labs'].includes(route)&&!flow.demo&&!flow.loading&&!flow.quoteLoaded[flow.kind]&&!flow.quoteError)quotes();
  }
  async function read(){
    stopReading();flow.running=true;const version=readVersion;
    if(flow.demo){
      const advance=()=>{if(version!==readVersion||lastRoute!=='reading')return;if(flow.stage<3){flow.stage++;render({keepScroll:true});readTimer=setTimeout(advance,1300);}else{flow.running=false;navigate('review');}};
      readTimer=setTimeout(advance,1800);return;
    }
    if(!prescriptionService?.read){flow.error='The reading service is not connected yet. Your file has not been uploaded. You can explore these screens with the sample parchi.';flow.running=false;render({keepScroll:true});return;}
    readRequest=new AbortController();
    try{
      const result=await prescriptionService.read({file:state.upload?.file,signal:readRequest.signal,onProgress:stage=>{if(version===readVersion&&lastRoute==='reading'){flow.stage=Math.max(1,Math.min(3,Number(stage)||1));render({keepScroll:true});}}});
      if(version!==readVersion||lastRoute!=='reading')return;
      if(!Array.isArray(result.items)||result.items.some(item=>!item.id||!item.name||!['medicine','test'].includes(item.kind)))throw new Error('The extracted list could not be read. Please try again.');
      flow.items=result.items.map(item=>({...item,selected:!item.unresolved,quantity:Number.isInteger(item.quantity)&&item.quantity>0?item.quantity:1}));
      flow.privacy=result.privacy;flow.running=false;navigate('review');
    }catch(error){if(version!==readVersion||error.name==='AbortError')return;flow.error=error.message||'We could not read this file. Please try another photo.';flow.running=false;render({keepScroll:true});}
  }
  function begin(source){
    stopReading();flow=fresh();flow.source=source;
    if(source==='upload'){flow.demo=false;flow.imageUrl=state.upload?.file.type.startsWith('image/')?state.upload.url:null;}
    if(source==='manual'){
      flow.demo=false;flow.items=state.manual.map((item,index)=>({id:`manual-${index}`,name:item.text,detail:'Entered manually · confirm against your prescription',kind:item.type==='Test'?'test':'medicine',quantity:1,selected:true}));
    }
    closeDialog();navigate(source==='manual'?'review':'reading');
  }
  function invalidate(){flow.offers={};flow.quoteLoaded={};flow.quoteError='';}
  function findOffer(id){return flow.offers[flow.kind]?.find(offer=>offer.id===id);}
  function details(offer){
    const complete=offer.availableCount===offer.requiredCount;
    showDialog(esc(offer.name),`<p><strong>${money(offer.pricePaise)}${!complete?' · Partial quote':''}</strong><br>${esc(offer.area)} · ${esc(offer.distance)} km<br>${esc(offer.readyLabel)}</p><p>${offer.availableCount==null?'A refreshed quote is needed for your edited list.':`${offer.availableCount} of ${offer.requiredCount} prescribed ${flow.kind==='test'?'tests':'items'} available.`}</p><ul class="dialog-item-list">${selectedItems(flow.items,flow.kind).map(item=>`<li>${esc(item.name)}${flow.kind==='medicine'?` × ${item.quantity}`:''}</li>`).join('')}</ul><p class="preview-note">${flow.demo?'Sample offer from the supplied design. Item-level fulfilment, final fees and stock have not been verified.':'Confirm final fees, exact items and timing with the provider.'}</p><button type="button" class="primary-action" data-select-offer="${esc(offer.id)}">Select this provider</button>`);
  }
  function resolveItem(item,name){
    item.name=name;item.choice=name;item.unresolved=false;item.userConfirmed=true;item.selected=true;
    flow.reviewError='';invalidate();
  }
  async function click(button){
    if(button.dataset.resolveItem){
      const item=flow.items.find(item=>item.id===button.dataset.resolveItem);
      if(item&&item.candidates.includes(button.dataset.candidate)){
        resolveItem(item,button.dataset.candidate);
        focusSelector=`[data-resolve-item="${CSS.escape(item.id)}"][data-candidate="${CSS.escape(item.choice)}"]`;
        render({keepScroll:true});
      }
      return true;
    }
    if(button.dataset.typeItem){
      const item=flow.items.find(item=>item.id===button.dataset.typeItem);if(!item)return true;
      showDialog('Type the correct name',`<p>Copy the exact name from your prescription. If you are unsure, check with your doctor or pharmacist.</p><form id="resolve-prescription-item" data-id="${esc(item.id)}"><label for="resolve-name">${item.kind==='test'?'Test name':'Medicine name and strength'}</label><input id="resolve-name" class="dialog-field" maxlength="150" value="${esc(item.choice||'')}" required><button type="submit" class="primary-action">Confirm name</button></form>`);
      return true;
    }

    if(button.dataset.reviewTab){flow.reviewTab=button.dataset.reviewTab;focusSelector=`[data-review-tab="${flow.reviewTab}"]`;render({keepScroll:true});return true;}
    if(button.dataset.compareTab){
      const kind=button.dataset.compareTab;
      if(kind==='all'){showDialog('Get It All',`<p>Select a medicine plan and a lab plan to review together.</p><p class="preview-note">The combined checkout screen will follow your next design reference.</p><button class="primary-action" type="button" data-close>Done</button>`);}
      else if(!selectedItems(flow.items,kind).length)toast(`Select at least one ${kind==='test'?'test':'medicine'} in your list first.`);
      else{focusSelector=`[data-compare-tab="${kind}"]`;navigate(kind==='test'?'labs':'medicines');}return true;
    }
    if(button.dataset.quantity){const item=flow.items.find(item=>item.id===button.dataset.quantity);if(item){item.quantity=Math.max(1,Math.min(99,item.quantity+Number(button.dataset.delta)));focusSelector=`[data-quantity="${CSS.escape(item.id)}"][data-delta="1"]`;invalidate();render({keepScroll:true});}return true;}
    if(button.dataset.editItem){
      const item=flow.items.find(item=>item.id===button.dataset.editItem);if(!item)return true;
      showDialog('Review item',`<form id="edit-prescription-item" data-id="${esc(item.id)}"><label for="edit-item-name">${item.kind==='test'?'Test':'Medicine name and strength'}</label><input id="edit-item-name" class="dialog-field" value="${esc(item.name)}" maxlength="150" required><label for="edit-item-detail">Details as prescribed</label><input id="edit-item-detail" class="dialog-field" value="${esc(item.schedule||item.detail)}" maxlength="200">${item.kind==='medicine'?`<label for="edit-item-quantity">Quantity</label><input id="edit-item-quantity" class="dialog-field" type="number" min="1" max="99" value="${item.quantity}" required>`:''}<p class="preview-note">Check the original prescription. Changing an item requires a fresh provider quote.</p><button class="primary-action" type="submit">Save changes</button><button class="dialog-secondary" type="button" data-delete-item="${esc(item.id)}">Remove item</button></form>`);return true;
    }
    if(button.dataset.deleteItem){flow.items=flow.items.filter(item=>item.id!==button.dataset.deleteItem);invalidate();closeDialog();render({keepScroll:true});return true;}
    if(button.dataset.selectOffer){const offer=findOffer(button.dataset.selectOffer);if(offer){flow.selected[flow.kind]=offer.id;closeDialog();render({keepScroll:true});}return true;}
    if(button.dataset.offerDetails){const offer=findOffer(button.dataset.offerDetails);if(offer)details(offer);return true;}
    const name=button.dataset.flow;if(!name)return false;
    if(name==='sample')begin('sample');
    if(name==='confirm-review'){
      const pending=flow.items.filter(item=>item.unresolved);
      if(pending.length){
        flow.reviewError='Please confirm or correct the highlighted items before continuing.';
        render({keepScroll:true});
        const card=document.querySelector(`#uncertainty-${CSS.escape(pending[0].id)}`);
        card?.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth',block:'center'});
        card?.querySelector('button')?.focus({preventScroll:true});return true;
      }
      if(!flow.items.length)return true;
      document.dispatchEvent(new CustomEvent('parchi:prescription-confirmed',{detail:{items:structuredClone(selectedItems(flow.items)),demo:flow.demo}}));
      navigate('plans');
    }
    if(name==='cancel'){stopReading();navigate('capture');}
    if(name==='view-image')showDialog('Uploaded image',`${prescriptionImage(flow,'dialog-preview-image')}<p class="preview-note">${flow.demo?'Reference sample prescription.':'Selected file preview. Verify all extracted details against the original.'}</p><button type="button" class="primary-action" data-close>Done</button>`);
    if(name==='stores'){const kind=flow.reviewTab==='test'&&selectedItems(flow.items,'test').length?'test':selectedItems(flow.items,'medicine').length?'medicine':'test';navigate(kind==='test'?'labs':'medicines');}
    if(name==='choose-area'){state.areaReturn=state.route;navigate('area');}
    if(name==='retry-quotes')await quotes();
    if(name==='filters')showDialog('Filter plans',`<form id="provider-filters"><fieldset class="filter-options"><legend>Show options that suit you</legend><label><input type="checkbox" name="complete" ${flow.onlyComplete?'checked':''}>${flow.kind==='test'?'All tests available':'All medicines available'}</label>${flow.kind==='test'?`<label><input type="checkbox" name="home" ${flow.homeOnly?'checked':''}>Home sample collection</label>`:''}</fieldset><button type="submit" class="primary-action">Apply filters</button></form>`);
    if(name==='map'){
      showDialog('Nearby providers',`<div class="dialog-map" id="provider-map">${glyph.map}<strong>Map unavailable</strong><p>Use the provider list to compare options.</p></div><p class="preview-note">No map tiles or location requests load in this preview.</p><button type="button" class="primary-action" data-close>Back to list</button>`);
      mapCleanup?.();try{mapCleanup=mapProvider.mount(document.querySelector('#provider-map'),{area:state.area,onSelect:()=>{},onStatus:status=>{const title=document.querySelector('#provider-map strong');if(title)title.textContent=status.message||'Map unavailable';}});}catch{mapCleanup=null;}
    }
    if(name==='continue-plan'){
      const offer=findOffer(flow.selected[flow.kind]);if(!offer||!Number.isInteger(offer.pricePaise)||!Number.isInteger(offer.availableCount)||offer.availableCount<=0||offer.availableCount!==offer.requiredCount)return true;
      document.dispatchEvent(new CustomEvent('parchi:plan-selected',{detail:{offer:structuredClone(offer),items:structuredClone(selectedItems(flow.items,flow.kind)),area:state.area,demo:flow.demo}}));
      showDialog('Your selected plan',`<p><strong>${esc(offer.name)} · ${money(offer.pricePaise)}</strong><br>${esc(offer.readyLabel)}</p><p>${flow.demo?'This is a sample plan. No order or booking has been placed.':'Your selection is ready for the checkout integration. No order or booking has been placed.'}</p><p class="preview-note">The next step will use your checkout screen design.</p><button type="button" class="primary-action" data-close>Done</button>`);
    }
    return true;
  }
  function change(target){
    if(target.dataset.itemSelect){const item=flow.items.find(item=>item.id===target.dataset.itemSelect);if(item){item.selected=target.checked;focusSelector=`[data-item-select="${CSS.escape(item.id)}"]`;invalidate();render({keepScroll:true});}return true;}
    if(target.id==='offer-sort'){flow.sort=target.value;focusSelector='#offer-sort';visible();render({keepScroll:true});return true;}
    return false;
  }
  function submit(form){
    if(form.id==='resolve-prescription-item'){
      const name=form.querySelector('#resolve-name').value.trim();if(!name)return true;
      const item=flow.items.find(item=>item.id===form.dataset.id);
      if(item)resolveItem(item,name);
      closeDialog();render({keepScroll:true});return true;
    }

    if(form.id==='edit-prescription-item'){
      const name=form.querySelector('#edit-item-name').value.trim();if(!name)return true;
      const item=flow.items.find(item=>item.id===form.dataset.id);if(item){item.name=name;item.detail=form.querySelector('#edit-item-detail').value.trim();if(item.schedule)item.schedule=item.detail;const quantity=form.querySelector('#edit-item-quantity');if(quantity)item.quantity=Number(quantity.value);item.userConfirmed=true;delete item.matchStatus;delete item.badge;delete item.crop;invalidate();}
      closeDialog();render({keepScroll:true});return true;
    }
    if(form.id==='provider-filters'){
      const data=new FormData(form);flow.onlyComplete=data.has('complete');flow.homeOnly=data.has('home');visible();
      if(!flow.visibleOffers.some(offer=>offer.id===flow.selected[flow.kind]))flow.selected[flow.kind]=flow.visibleOffers[0]?.id;
      closeDialog();render({keepScroll:true});return true;
    }
    return false;
  }
  function dialogClosed(){mapCleanup?.();mapCleanup=null;}
  return {resetSession(){stopReading();quoteRequest?.abort();quoteVersion++;flow=fresh();lastRoute=null;},prepare,mounted,begin,click,change,submit,dialogClosed,screen:route=>route==='reading'?readingScreen(flow):route==='review'?reviewScreen(flow):compareScreen(flow,state.area)};
}
