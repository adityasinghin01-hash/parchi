import {esc} from './components/ui.js';
import {historyFixture} from './services/profile-fixtures.js';
import {historyScreen} from './screens/history.js';
import {accountScreen} from './screens/account.js';
import {rankingScreen} from './screens/ranking.js';
export const profileRoutes=['history','account','ranking'];
export function createProfileScreens({state,preferences,navigate,render,showDialog,closeDialog,toast,logout,journey}){
 const model={history:structuredClone(historyFixture),historyFilter:'all',profile:{phone:'9876543210',mode:'demo',verified:true},source:'reference-demo',firstName:'',lastName:'',language:'en',notifications:true,appearance:'system',rankReturn:'plans',loggedOut:false,loading:false,error:''};
 // Appearance preference does not override the user-approved brand palette.
 function appearance(){document.body.dataset.appearance='light';document.documentElement.style.colorScheme='light';}
 appearance();
 function radioForm(id,legend,options,current){return `<form id="${id}"><div class="preference-radio-list" role="group" aria-label="${legend}">${options.map(([value,label])=>`<label><span>${label}</span><input type="radio" name="choice" value="${value}" ${value===current?'checked':''} required></label>`).join('')}</div><p class="preview-note">${id==='account-appearance'?'Your preference is saved. This preview keeps Parchi’s cream, orange and yellow theme.':'Preferences are saved for this preview.'}</p><button type="submit" class="primary-action">Save</button></form>`;}
 function detail(record){showDialog(esc(record.name),`<p>${esc(record.date)} · ${esc(record.status)}<br>${record.medicines} medicines · ${record.tests} lab tests</p><p class="preview-note">Sample history entry. Exact medicine names, seller order references and reports have not been connected.</p>${record.action==='pass'?`<button type="button" class="primary-action" data-history-action="${record.id}">View Parchi Pass</button>`:'<button type="button" class="primary-action" data-close>Done</button>'}`);}
 function showPass(){if(model.source!=='reference-demo'){showDialog('Parchi Pass',`<p>Your historical pass is not connected yet.</p><button type="button" class="primary-action" data-close>Done</button>`);return;}closeDialog();journey.openReferencePass('history');navigate('pass');}
 async function click(button){
  if(button.dataset.journey==='ranking'){model.rankReturn=['plans','plan-map','get-all'].includes(state.route)?state.route:'plans';navigate('ranking');return true;}
  if(button.dataset.historyFilter){model.historyFilter=button.dataset.historyFilter;render({keepScroll:true});document.querySelector(`[data-history-filter="${model.historyFilter}"]`)?.focus({preventScroll:true});return true;}
  if(button.dataset.historyDetails){const record=model.history.find(item=>item.id===button.dataset.historyDetails);if(record)detail(record);return true;}
  if(button.dataset.historyAction){const record=model.history.find(item=>item.id===button.dataset.historyAction);if(!record)return true;
   if(record.action==='pass'){showPass();return true;}
   if(record.action==='reorder'){showDialog('Reorder medicines',`<p>${esc(record.name)} · ${esc(record.date)}<br>${record.medicines} medicines</p><p>The sample record does not include medicine names. Add the original prescription to review the exact items and get fresh prices.</p><button type="button" class="primary-action" data-nav="capture">Add prescription</button><button type="button" class="dialog-secondary" data-close>Back to history</button>`);return true;}
   if(record.action==='report'){showDialog('Report not connected',`<p>${esc(record.name)} · ${esc(record.date)}</p><p>The original lab report has not been connected. No test results are generated in this preview.</p><button type="button" class="primary-action" data-close>Done</button>`);return true;}
   detail(record);return true;
  }
  const action=button.dataset.final;if(!action)return false;
  if(action==='name')showDialog(model.firstName?'Edit your name':'Add your name',`<form id="account-name"><label for="account-first-name">First name (required)</label><input id="account-first-name" class="dialog-field" autocomplete="given-name" maxlength="80" value="${esc(model.firstName)}" required><label for="account-last-name">Last name (optional)</label><input id="account-last-name" class="dialog-field" autocomplete="family-name" maxlength="80" value="${esc(model.lastName)}"><button type="submit" class="primary-action">Save name</button></form>`);
  if(action==='addresses'){state.areaReturn='account';navigate('area');}
  if(action==='pass'){if(model.source==='reference-demo'){journey.openReferencePass('account');navigate('pass');}else showPass();}
  if(action==='language')showDialog('Preferred language',radioForm('account-language','Preferred language',[['en','English'],['hi','हिन्दी · Hindi']],model.language));
  if(action==='appearance')showDialog('Appearance',radioForm('account-appearance','Appearance',[['system','System'],['light','Light'],['dark','Dark']],model.appearance));
  if(action==='notifications')showDialog('Notifications',`<form id="account-notifications"><label class="preference-option"><span>Medicine, test and order alerts</span><input type="checkbox" name="enabled" ${model.notifications?'checked':''}></label><p class="preview-note">This saves your preference. Device permissions and notification delivery are not connected.</p><button type="submit" class="primary-action">Save preference</button></form>`);
  if(action==='privacy')showDialog('Privacy & Settings',`<form id="account-privacy">${[['location','Location'],['camera','Camera'],['photos','Photos'],['usage','Optional usage data']].map(([id,label])=>`<label class="preference-option"><span>${label}</span><input type="checkbox" name="${id}" ${preferences[id]?'checked':''}></label>`).join('')}<p class="preview-note">Preview choices only. These do not request device access, upload files or send usage data.</p><button type="submit" class="primary-action">Save choices</button></form><button type="button" class="dialog-secondary" data-final="logout">Clear preview details</button>`);
  if(action==='logout')showDialog('Log out of this preview?',`<p>Your unsaved profile, selected file, order notes and preferences on this page will be cleared.</p><button type="button" class="primary-action" data-final="confirm-logout">Log out</button><button type="button" class="dialog-secondary" data-close>Cancel</button>`);
  if(action==='confirm-logout'){model.firstName='';model.lastName='';model.profile=null;model.loggedOut=true;model.history=[];model.source='local-preview';model.language='en';model.notifications=false;model.appearance='system';appearance();closeDialog();logout();}
  if(action==='older-history')showDialog('Older history',`<p>No older records are connected in this preview. Available sample entries cover August–October 2026.</p><button type="button" class="primary-action" data-nav="account">Open Account</button>`);
  if(action==='price-sources')showDialog('Where prices come from',`<p>Each price should identify its seller or published source, when it was checked and whether it is a quote, reference or estimate.</p><p>This preview uses the supplied screen references. Live seller quotes, complete fees and comparison-price sources are not connected. Unknown fees are not treated as zero.</p><button type="button" class="primary-action" data-close>Done</button>`);
  return true;
 }
 function submit(form){
  if(form.id==='account-name'){const first=form.querySelector('#account-first-name').value.trim();if(!first){form.querySelector('#account-first-name').setCustomValidity('Enter your first name.');form.reportValidity();return true;}model.firstName=first;model.lastName=form.querySelector('#account-last-name').value.trim();closeDialog();render({keepScroll:true});return true;}
  if(form.id==='account-language'){model.language=new FormData(form).get('choice');closeDialog();render({keepScroll:true});toast('Language preference saved for this preview.');return true;}
  if(form.id==='account-appearance'){model.appearance=new FormData(form).get('choice');appearance();closeDialog();render({keepScroll:true});return true;}
  if(form.id==='account-notifications'){model.notifications=new FormData(form).has('enabled');closeDialog();render({keepScroll:true});return true;}
  if(form.id==='account-privacy'){const data=new FormData(form);for(const id of ['location','camera','photos','usage'])preferences[id]=data.has(id);closeDialog();toast('Preview choices saved. No device access requested.');return true;}
  return false;
 }
 function input(target){if(target.id==='account-first-name')target.setCustomValidity('');}
 return {click,submit,input,screen:route=>route==='history'?historyScreen(model,state):route==='account'?accountScreen(model,state):rankingScreen(model,state)};
}
