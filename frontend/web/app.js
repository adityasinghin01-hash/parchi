import {createProfileScreens,profileRoutes} from './profile.js';
import {createJourney,journeyRoutes} from './journey.js';
import { createPrescriptionFlow, prescriptionRoutes } from './prescription-flow.js';
import { icons } from './components/icons.js';
import { esc, glyph, referenceArt } from './components/ui.js';
import { permissions, welcomeScreen } from './screens/welcome.js';
import { signinScreen, otpScreen } from './screens/auth.js';
import { homeScreen, recentRow } from './screens/home.js';
import { areaScreen } from './screens/area.js';
import { captureScreen } from './screens/capture.js';
import { services, validPhone } from './services/api.js';
import { mapProvider } from './services/map.js';
import { citiesFixture, filesFixture } from './services/fixtures.js';

const app=document.querySelector('#app');
const dialog=document.querySelector('#preference-dialog');
const routes=new Set(['welcome','signin','verify','home','area','capture',...prescriptionRoutes,...journeyRoutes,...profileRoutes]);
const preferences={location:false,camera:false,photos:false,notifications:false,usage:false};
const state={route:'welcome',phone:'',otp:'',challenge:null,profile:null,busy:false,error:'',home:null,homeSearch:'',areas:null,area:null,areaDraft:null,areaSearch:'',locationStatus:'',upload:null,manual:[]};
let opener=null,renderId=0,requestController=null,mapCleanup=null,toastTimer=null,searchTimer=null,authRequestId=0;
const flow=createPrescriptionFlow({state,navigate,render,showDialog,closeDialog,toast,mapProvider});
const journey=createJourney({state,navigate,render,showDialog,closeDialog,toast,mapProvider});
const profiles=createProfileScreens({state,preferences,navigate,render,showDialog,closeDialog,toast,logout:logoutPreview,journey});
document.addEventListener('parchi:prescription-confirmed',event=>journey.requirements(event.detail));
document.querySelector('#device-indicators').innerHTML=icons.status;

function currentRoute(){const name=location.hash.replace(/^#\/?/,'').split('?')[0];return ['medicines','labs'].includes(name)?'plans':routes.has(name)?name:'welcome';}
function navigate(route){if(!routes.has(route))return;authRequestId++;state.error='';state.busy=false;if(location.hash===`#/${route}`)render();else location.hash=`/${route}`;}
function showDialog(title,content){
  if(dialog.open)dialog.close();
  opener=document.activeElement;
  dialog.innerHTML=`<div class="dialog-header"><h2 id="dialog-title">${title}</h2><button type="button" class="close-button" data-close aria-label="Close">${icons.close}</button></div>${content}`;
  dialog.showModal();
}
function closeDialog(){dialog.close();flow.dialogClosed();journey.dialogClosed();if(opener?.isConnected)opener.focus({preventScroll:true});}
function toast(message){
  document.querySelector('.toast')?.remove();clearTimeout(toastTimer);
  const node=document.createElement('div');node.className='toast';node.setAttribute('role','status');node.textContent=message;document.body.append(node);
  toastTimer=setTimeout(()=>node.remove(),4000);
}
function option(id,title){return `<label class="preference-option"><span>${title}</span><input type="checkbox" data-preference="${id}" ${preferences[id]?'checked':''}></label>`;}
function setError(message,target){state.error=message;const el=document.querySelector(target);if(el)el.textContent=message;else toast(message);}

async function render({keepScroll=false}={}){
  const savedScroll=window.scrollY;
  const id=++renderId;
  requestController?.abort();requestController=new AbortController();
  mapCleanup?.();mapCleanup=null;
  state.route=currentRoute();flow.prepare(state.route);journey.prepare(state.route);
  if(state.route==='verify'&&!state.challenge){navigate('signin');return;}
  const titles={welcome:'Welcome',signin:'Let’s get you started',verify:'Verify your phone number',home:'Home',area:'Choose your area',capture:'Capture or import your parchi',reading:'Reading your parchi',review:'Review your parchi',medicines:'Compare medicine plans',labs:'Compare lab test plans',plans:'Plan Comparison','plan-map':'Plan Comparison · Map','get-all':'Get it all review',checkout:'Checkout Assistant',track:'Your order is on track',care:'Care for better health',pass:'Parchi Pass',history:'Your History',account:'Account',ranking:'How We Rank'};
  document.title=`Parchi · ${titles[state.route]}`;
  const views={welcome:welcomeScreen,signin:()=>signinScreen(state),verify:()=>otpScreen(state),home:()=>homeScreen(state),area:()=>areaScreen(state),capture:()=>captureScreen(state),...Object.fromEntries(prescriptionRoutes.map(route=>[route,()=>flow.screen(route)])),...Object.fromEntries(journeyRoutes.map(route=>[route,()=>journey.screen(route)])),...Object.fromEntries(profileRoutes.map(route=>[route,()=>profiles.screen(route)]))};
  app.innerHTML=views[state.route]();
  document.querySelector('.phone-preview').dataset.screen=state.route;
  if(keepScroll)window.scrollTo(0,savedScroll);else window.scrollTo(0,0);
  flow.mounted(state.route);journey.mounted(state.route);
  if(state.route==='verify')refreshOtp();
  if(state.route==='capture'&&state.pendingPicker){const picker=state.pendingPicker;state.pendingPicker=null;document.querySelector(picker)?.click();}
  if(state.route==='home'&&!state.home){
    try{const data=await services.getHome({signal:requestController.signal});if(id!==renderId)return;state.home=data;state.error='';render({keepScroll:true});}
    catch(error){if(id!==renderId||error.name==='AbortError')return;state.error=error.message;app.innerHTML=homeScreen(state);}
  }
  if(state.route==='area'){
    if(!state.areas){
      try{const data=await services.getAreas({signal:requestController.signal});if(id!==renderId)return;state.areas=data;state.areaDraft=data.saved[0]||null;state.error='';render({keepScroll:true});}
      catch(error){if(id!==renderId||error.name==='AbortError')return;setError(error.message,'#area-error');}
    }else mountMap();
  }
}
function mountMap(){
  const element=document.querySelector('#area-map');if(!element)return;
  try{
    const cleanup=mapProvider.mount(element,{area:state.areaDraft,onSelect:area=>{state.areaDraft=area;render({keepScroll:true});},onStatus:status=>{
      element.dataset.mapStatus=status.state;
      if(status.state==='unavailable'||status.state==='error'){
        const title=element.querySelector('strong');if(title)title.textContent=status.message||'Map unavailable';
      }
    }});
    mapCleanup=typeof cleanup==='function'?cleanup:null;
  }catch{element.dataset.mapStatus='error';const title=element.querySelector('strong');if(title)title.textContent='Map unavailable';else element.textContent='Map unavailable. Choose an area below.';}
}
function refreshOtp(){
  if(state.route!=='verify'||!state.challenge)return;
  const seconds=Math.max(0,Math.ceil((state.challenge.resendAt-Date.now())/1000));
  const resend=document.querySelector('#resend-button');
  if(resend){resend.disabled=seconds>0||state.busy;resend.innerHTML=seconds>0?`Resend in <span id="resend-timer">00:${String(seconds).padStart(2,'0')}</span>`:'Resend code';}
  document.querySelectorAll('.otp-cell').forEach((cell,index)=>{cell.classList.toggle('is-active',index===state.otp.length);cell.innerHTML=state.otp[index]||'<i></i>';});
  const input=document.querySelector('#otp-code');if(input&&input.value!==state.otp)input.value=state.otp;
  const verify=document.querySelector('#verify-button');if(verify)verify.disabled=state.otp.length!==6||state.busy;
}
setInterval(refreshOtp,1000);

async function sendOtp({resend=false}={}){
  if(state.busy)return;
  const number=document.querySelector('#phone-number');if(number)state.phone=number.value;
  if(!validPhone(state.phone)){setError('Enter a valid 10-digit mobile number.','#phone-error');number?.setAttribute('aria-invalid','true');number?.focus();return;}
  const authId=++authRequestId;state.busy=true;state.error='';
  if(resend)refreshOtp();else await render({keepScroll:true});
  try{
    const challenge=await services.startOtp(state.phone);if(authId!==authRequestId)return;state.challenge=challenge;state.otp='';state.busy=false;
    if(resend){setError('','#otp-error');refreshOtp();toast(services.mode==='demo'?'Demo code refreshed: 482931. No SMS sent.':'A new code has been requested.');}
    else navigate('verify');
  }catch(error){if(authId!==authRequestId)return;state.busy=false;state.error=error.message;if(resend){setError(error.message,'#otp-error');refreshOtp();}else render({keepScroll:true});}
}
async function verifyOtp(){
  if(state.busy||state.otp.length!==6)return;
  const authId=++authRequestId;state.busy=true;refreshOtp();document.querySelector('#verify-button').textContent='Verifying…';
  try{const profile=await services.verifyOtp(state.challenge.id,state.otp);if(authId!==authRequestId)return;state.profile=profile;state.isGuest=false;state.otp='';state.challenge=null;state.busy=false;navigate('home');}
  catch(error){if(authId!==authRequestId)return;state.busy=false;setError(error.message,'#otp-error');document.querySelector('#verify-button').innerHTML=`Verify & Continue ${icons.arrow}`;refreshOtp();}
}

function showTab(tab){const target={home:'home',account:'account',parchis:'history',track:'track',care:'care'}[tab];if(target)navigate(target);}
function logoutPreview(){
  authRequestId++;requestController?.abort();
  if(state.upload?.url)URL.revokeObjectURL(state.upload.url);
  Object.assign(state,{phone:'',otp:'',challenge:null,profile:null,isGuest:true,busy:false,error:'',home:null,homeSearch:'',areas:null,area:null,areaDraft:null,areaSearch:'',searchResults:[],locationStatus:'',upload:null,manual:[],pendingPicker:null,areaReturn:null});
  for(const key of Object.keys(preferences))preferences[key]=false;
  flow.resetSession();journey.resetSession();navigate('signin');
}
function showInfo(name){
  const entries={
    how:['How Parchi works','Add your prescription, review the extracted details, compare your options, then choose your next step.'],
    terms:['Terms of Service','Terms have not been connected in this design preview. No purchase, account or paid service is created here.'],
    privacy:['Privacy Policy','This preview keeps form details and selected files in this page’s memory. It does not send them to a server. Device permission and privacy-processing features will be connected in the native app.']
  };
  const [title,copy]=entries[name]||['Parchi',''];
  showDialog(title,`<p>${copy}</p><button type="button" class="primary-action" data-close>Done</button>`);
}
function openPicker(id){
  if(dialog.open)closeDialog();
  if(state.route!=='capture'){state.pendingPicker=id;navigate('capture');}
  else document.querySelector(id)?.click();
}
function showUpload(){
  if(!state.upload)return;
  const {file,url,name}=state.upload;
  const preview=file.type.startsWith('image/')?`<img class="dialog-preview-image" src="${esc(url)}" alt="Selected prescription preview">`:`<p>PDF selected: ${esc(name)}</p>`;
  showDialog('Use this file?',`${preview}<p class="preview-note">Stays on this device in this preview. No OCR or upload runs.</p><button class="primary-action" type="button" data-action="use-upload">Use photo or file</button><button class="dialog-secondary" type="button" data-close>Choose again</button>`);
}
function receiveFile(file){
  if(!file)return;
  if(file.size>15*1024*1024){toast('Choose a file smaller than 15 MB.');return;}
  if(!file.type.startsWith('image/')&&file.type!=='application/pdf'){toast('Choose an image or PDF file.');return;}
  if(state.upload?.url)URL.revokeObjectURL(state.upload.url);
  state.upload={file,name:file.name,url:URL.createObjectURL(file)};showUpload();
}
function showManual(){
  showDialog('Enter medicines and tests',`<p>Copy what the doctor wrote. This preview does not recommend or match medicines.</p><form id="manual-form"><label for="manual-type">Type</label><select class="dialog-field" id="manual-type"><option>Medicine</option><option>Test</option></select><label for="manual-name">Name and details</label><input class="dialog-field" id="manual-name" maxlength="200" placeholder="Name, strength and quantity as written" required><button type="submit" class="primary-action">Add item</button></form><div id="manual-items">${state.manual.map((item,index)=>`<div class="manual-item"><span>${esc(item.type)} · ${esc(item.text)}</span><button type="button" data-remove-manual="${index}" aria-label="Remove ${esc(item.text)}">Remove</button></div>`).join('')}</div>${state.manual.length?'<button type="button" class="dialog-secondary" data-action="use-manual">Save list preview</button>':''}`);
}

async function action(name,button){
  if(name==='guest'){state.isGuest=true;state.profile=null;navigate('home');}
  if(name==='resend')await sendOtp({resend:true});
  if(name==='start-capture')navigate('capture');
  if(name==='retry-home'){state.home=null;state.error='';render();}
  if(name==='pick-photos')openPicker('#photo-picker');
  if(name==='pick-files')openPicker('#file-picker');
  if(name==='take-photo')openPicker('#camera-picker');
  if(name==='camera-flash')toast('Flash control will be connected to the native camera. This scene is a sample preview.');
  if(name==='preview-upload')showUpload();
  if(name==='manual-entry')showManual();
  if(name==='whatsapp-import')showDialog('Import from WhatsApp',`<p>Save the prescription image from WhatsApp, then choose it from Photos or Files.</p><p class="preview-note">The native iOS app will receive images through its share extension. This browser preview does not access your chats.</p><button type="button" class="primary-action" data-action="pick-photos">Choose from Photos</button>`);
  if(name==='use-upload'){
    closeDialog();document.dispatchEvent(new CustomEvent('parchi:capture-selected',{detail:{file:state.upload.file,source:'local-file'}}));
    flow.begin('upload');
  }
  if(name==='use-manual'){closeDialog();document.dispatchEvent(new CustomEvent('parchi:capture-selected',{detail:{items:cloneManual(),source:'manual'}}));flow.begin('manual');}
  if(name==='all-files')showDialog('Recent sample files',`${filesFixture.map(file=>`<button type="button" class="dialog-secondary" data-file="${file.id}">${esc(file.name)} · ${esc(file.date)}</button>`).join('')}<p class="preview-note">Images and labels from the supplied design reference.</p>`);
  if(name==='clear-recent'){if(state.areas){state.areas.recent=[];render({keepScroll:true});}}
  if(name==='more-cities')showDialog('Choose a city',`${citiesFixture.filter(city=>city.id!=='more').map(city=>`<button type="button" class="dialog-secondary" data-city="${city.id}">${city.label}</button>`).join('')}<p class="preview-note">City labels are design fixtures. Live availability is not confirmed.</p>`);
  if(name==='manage-areas')showDialog('Saved areas',`<p>Add an area name for this preview.</p><form id="manage-area-form"><label for="new-area-name">Label</label><input id="new-area-name" class="dialog-field" maxlength="50" placeholder="Home or Work" required><label for="new-area-detail">Area, city or PIN code</label><input id="new-area-detail" class="dialog-field" maxlength="200" required><button type="submit" class="primary-action">Save area</button></form>`);
  if(name==='current-location'){
    if(services.mode==='demo'){setError('Current location lookup is not connected. Choose an area manually.','#area-error');return;}
    if(!navigator.geolocation){setError('Location is unavailable. Choose your area manually.','#area-error');return;}
    state.locationStatus='Finding your location…';button.disabled=true;
    navigator.geolocation.getCurrentPosition(async pos=>{
      try{state.areaDraft=await services.resolveLocation({latitude:pos.coords.latitude,longitude:pos.coords.longitude});state.locationStatus=state.areaDraft.detail||state.areaDraft.label;state.error='';render({keepScroll:true});}
      catch(error){state.locationStatus='Choose an area manually';setError(error.message,'#area-error');button.disabled=false;}
    },()=>{state.locationStatus='Permission unavailable';setError('Location access is off. Choose an area manually.','#area-error');button.disabled=false;},{timeout:10000,maximumAge:60000});
  }
  if(name==='confirm-area'){
    if(!state.areaDraft||state.busy)return;
    state.busy=true;button.disabled=true;
    try{state.area=await services.confirmArea(state.areaDraft);state.busy=false;document.dispatchEvent(new CustomEvent('parchi:area-selected',{detail:state.area}));const destination=state.areaReturn||'home';state.areaReturn=null;navigate(destination);}
    catch(error){state.busy=false;button.disabled=false;setError(error.message,'#area-error');}
  }
}
function cloneManual(){return state.manual.map(item=>({...item}));}

async function clicks(event){
  const button=event.target.closest('button');if(!button)return;
  if(button.hasAttribute('data-close')){closeDialog();return;}
  if(button.dataset.captureMode){state.captureMode=button.dataset.captureMode;render({keepScroll:true});document.querySelector(`[data-capture-mode="${state.captureMode}"]`)?.focus({preventScroll:true});return;}
  if(await profiles.click(button))return;
  if(await journey.click(button))return;
  if(await flow.click(button))return;
  if(button.dataset.permission){
    const permission=permissions.find(item=>item.id===button.dataset.permission);
    const controls=permission.id==='camera'?option('camera','Camera')+option('photos','Photos'):option(permission.id,permission.id==='usage'?'Share usage data':permission.title);
    showDialog(permission.title,`<p>${permission.detail}</p>${controls}<p class="preview-note">UI preview only. These switches do not request device permissions or send data.</p><button type="button" class="primary-action" data-close>Done</button>`);return;
  }
  if(button.dataset.continue){state.isGuest=button.dataset.continue==='guest';document.dispatchEvent(new CustomEvent('parchi:welcome-complete',{detail:{choice:button.dataset.continue,preferences:{...preferences}}}));navigate(button.dataset.continue==='guest'?'home':'signin');return;}
  if(button.dataset.nav){if(dialog.open)closeDialog();navigate(button.dataset.nav);return;}
  if(button.dataset.tab){showTab(button.dataset.tab);return;}
  if(button.dataset.info){showInfo(button.dataset.info);return;}
  if(button.dataset.action){await action(button.dataset.action,button);return;}
  if(button.dataset.key){state.otp=button.dataset.key==='erase'?state.otp.slice(0,-1):(state.otp+button.dataset.key).slice(0,6);refreshOtp();document.querySelector('#otp-code')?.focus({preventScroll:true});return;}
  if(button.dataset.areaId){
    state.areaDraft=[...(state.areas?.saved||[]),...(state.areas?.recent||[]),...(state.searchResults||[])].find(area=>area.id===button.dataset.areaId)||null;state.error='';render({keepScroll:true});return;
  }
  if(button.dataset.city){
    if(button.dataset.city==='more'){action('more-cities',button);return;}
    const city=citiesFixture.find(item=>item.id===button.dataset.city);state.areaDraft={id:city.id,label:city.label,city:city.label};state.error='';if(dialog.open)closeDialog();render({keepScroll:true});return;
  }
  if(button.dataset.freeArea){state.areaDraft={id:crypto.randomUUID(),label:state.areaSearch,detail:state.areaSearch,city:state.areaSearch};state.areaSearch='';render({keepScroll:true});return;}
  if(button.dataset.recent){const item=state.home?.recent.find(entry=>entry.id===button.dataset.recent);if(item)showDialog(esc(item.name),`<p>${esc(item.summary)}<br>${esc(item.date)} · ${esc(item.status)}</p><p class="preview-note">Sample parchi from the design reference. A real record has not been loaded.</p><button type="button" class="primary-action" data-nav="capture">Add your parchi</button>`);return;}
  if(button.dataset.file){const file=filesFixture.find(entry=>entry.id===button.dataset.file);if(file)showDialog(esc(file.name),`${referenceArt('capture',file.crop,'dialog-preview-image')}<p class="preview-note">Sample thumbnail from the reference image · ${esc(file.date)}</p><button type="button" class="primary-action" data-flow="sample">Use sample parchi</button><button type="button" class="dialog-secondary" data-action="pick-files">Choose your file</button>`);return;}
  if(button.dataset.removeManual!==undefined){state.manual.splice(Number(button.dataset.removeManual),1);showManual();}
}
app.addEventListener('click',clicks);dialog.addEventListener('click',clicks);
dialog.addEventListener('input',event=>profiles.input(event.target));
dialog.addEventListener('cancel',event=>{event.preventDefault();closeDialog();});
dialog.addEventListener('change',event=>{if(event.target.dataset.preference)preferences[event.target.dataset.preference]=event.target.checked;});
app.addEventListener('change',event=>{if(journey.change(event.target)||flow.change(event.target))return;if(['photo-picker','camera-picker','file-picker'].includes(event.target.id))receiveFile(event.target.files[0]);});
app.addEventListener('input',event=>{
  const el=event.target;journey.input(el);profiles.input(el);
  if(el.id==='phone-number'){state.phone=el.value;el.removeAttribute('aria-invalid');setError('','#phone-error');}
  if(el.id==='otp-code'){state.otp=el.value.replace(/[०-९]/g,d=>'०१२३४५६७८९'.indexOf(d)).replace(/\D/g,'').slice(0,6);setError('','#otp-error');refreshOtp();}
  if(el.id==='home-search'){
    state.homeSearch=el.value;const list=state.home?.recent.filter(item=>(item.name+' '+item.summary+' '+item.status).toLowerCase().includes(el.value.toLowerCase()))||[];
    document.querySelector('#recent-rows').innerHTML=list.length?list.map(recentRow).join(''):'<p class="muted-copy">No matching sample parchis</p>';
  }
  if(el.id==='area-search'){
    state.areaSearch=el.value;clearTimeout(searchTimer);
    searchTimer=setTimeout(async()=>{
      const query=state.areaSearch.trim();const current=query;
      const results=document.querySelector('#area-search-results');if(!results)return;
      results.hidden=!query;if(!query){results.innerHTML='';return;}
      results.textContent='Searching…';
      try{const areas=await services.searchAreas(query);if(state.route!=='area'||state.areaSearch.trim()!==current)return;state.searchResults=areas;results.innerHTML=areas.map(area=>`<button type="button" data-area-id="${esc(area.id)}">${esc(area.label)}${area.detail?`<small>${esc(area.detail)}</small>`:''}</button>`).join('')+(services.mode==='demo'?`<button type="button" data-free-area="yes">Use “${esc(query)}”<small>Manual preview selection</small></button>`:'');if(!results.innerHTML)results.textContent='No areas found. Try another city or PIN code.';}
      catch(error){if(results.isConnected)results.textContent=error.message;}
    },200);
  }
});
app.addEventListener('submit',event=>{event.preventDefault();if(event.target.id==='phone-form')sendOtp();if(event.target.id==='otp-form')verifyOtp();});
dialog.addEventListener('submit',event=>{
  event.preventDefault();if(profiles.submit(event.target)||journey.submit(event.target)||flow.submit(event.target))return;
  if(event.target.id==='manage-area-form'){
    const label=dialog.querySelector('#new-area-name').value.trim();const detail=dialog.querySelector('#new-area-detail').value.trim();if(!label||!detail)return;
    const area={id:crypto.randomUUID(),label,detail,city:detail,icon:'home'};state.areas.saved.push(area);state.areaDraft=area;closeDialog();render({keepScroll:true});
  }
  if(event.target.id==='manual-form'){
    const text=dialog.querySelector('#manual-name').value.trim();if(!text)return;
    state.manual.push({type:dialog.querySelector('#manual-type').value,text});showManual();
  }
});
app.addEventListener('keydown',event=>{
  if(!['ArrowLeft','ArrowRight','Home','End'].includes(event.key))return;
  const tab=event.target.closest('[role=tab]');if(!tab)return;
  const tabs=[...tab.parentElement.querySelectorAll('[role=tab]')];
  const index=event.key==='Home'?0:event.key==='End'?tabs.length-1:(tabs.indexOf(tab)+(event.key==='ArrowRight'?1:-1)+tabs.length)%tabs.length;
  event.preventDefault();tabs[index].focus();tabs[index].click();
});
window.addEventListener('hashchange',()=>{authRequestId++;state.busy=false;render();});
window.addEventListener('beforeunload',()=>{if(state.upload?.url)URL.revokeObjectURL(state.upload.url);});
render();
