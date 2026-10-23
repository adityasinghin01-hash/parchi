import {brand,back,esc,glyph,referenceArt} from '../components/ui.js';
import {icons} from '../components/icons.js';
export function prescriptionImage(flow,cls=''){
  if(flow.imageUrl)return `<img class="${cls}" src="${esc(flow.imageUrl)}" alt="Selected prescription, visually obscured in this preview">`;
  if(!flow.demo)return `<div class="document-preview ${cls}" role="img" aria-label="${flow.source==='manual'?'Manually entered list':'Selected PDF file'}">${glyph.document}</div>`;
  return referenceArt('capture-camera',[178,416,551,713],cls);
}
export function readingScreen(flow){
  const steps=[['Image uploaded','Keeping it secure'],['Reading text','Finding medicines and tests…'],['Checking details','Organising and removing duplicates'],['Almost ready','This usually takes a few seconds']];
  if(!flow.demo)steps[0]=['Image selected','Kept on this device until processing is connected'];
  return `<section class="screen reading-screen">${back('capture')}<header class="flow-brand">${brand({compact:true})}</header>
    <h1>Reading your <em>parchi</em>…</h1><p class="flow-lead">We are securely reading the medicines and tests<br class="wide-only"> from your image.</p>
    <div class="reading-photo">${prescriptionImage(flow,'prescription-photo')}<div class="privacy-overlay">${glyph.lock}<span>${flow.demo?'Your prescription is blurred<br>for your privacy':'Preview hidden on this screen<br>Privacy processing is not connected'}</span></div></div>
    <div class="reading-steps" role="status" aria-live="polite">${steps.map(([title,detail],index)=>`<div class="reading-step ${index<flow.stage?'is-complete':index===flow.stage?'is-current':''}"><span class="step-mark">${index<flow.stage?glyph.check:''}</span><div><strong>${title}</strong><p>${detail}</p></div></div>`).join('')}</div>
    <aside class="reading-privacy">${icons.shield}<div><h2>Your privacy comes first</h2>${flow.demo?'<ul><li>Images are securely processed</li><li>Not shared with anyone</li><li>Only used to extract your medicines and tests</li></ul>':'<p class="processing-note">Visual hiding in this preview is not secure redaction. Privacy processing must be confirmed by the reading service.</p>'}</div></aside>
    ${flow.error?`<div class="flow-error" role="alert"><p>${esc(flow.error)}</p><button type="button" class="text-action" data-flow="sample">Try the sample parchi</button></div>`:''}
    <button type="button" class="cancel-reading" data-flow="cancel">Cancel</button><p class="reference-disclosure">${flow.demo?'Reference demo · sample image and simulated progress':'Local preview · no verified redaction or upload yet'}</p>
  </section>`;
}
