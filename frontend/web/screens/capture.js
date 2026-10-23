import {glyph,referenceArt,esc} from '../components/ui.js';
import {scanHeader,scanGlyph} from '../components/scan-ui.js';

export function captureScreen(state){
  const documentMode=state.captureMode==='document';
  return `<section class="screen scan-screen camera-screen" aria-label="Capture parchi">${scanHeader('Capture parchi','home')}
    <div class="camera-viewfinder" aria-label="Sample camera scene; live camera is not connected">
      ${referenceArt('capture-camera',[96,430,36,650],'camera-wood','none')}
      ${referenceArt('capture-camera',[88,260,154,143],'camera-plant')}
      <div class="camera-guidance">Fill the frame, avoid glare,<br>keep all edges visible.</div>
      <button type="button" class="camera-flash" data-action="camera-flash" aria-label="Flash unavailable in browser preview">${scanGlyph.flash}</button>
      <div class="camera-paper">${referenceArt('capture-camera',[178,416,551,713],'camera-paper-art')}</div>
      <div class="document-frame" aria-hidden="true"><i></i><i></i><i></i><i></i></div>
      <button type="button" class="camera-quality" data-flow="sample" aria-label="Preview reading with the sample parchi">${glyph.checkCircle}<span>Looks good!</span></button>
      <span class="camera-demo-label">Sample preview</span>
    </div>
    <div class="camera-controls"><div class="camera-actions"><button type="button" class="camera-import" data-action="pick-photos"><span>${glyph.photo}</span><strong>Photos</strong></button><button type="button" class="camera-shutter" data-action="${documentMode?'pick-files':'take-photo'}" aria-label="${documentMode?'Choose a document':'Take a photo'}"><span></span></button><button type="button" class="camera-import" data-action="pick-files"><span>${glyph.document}</span><strong>Import file</strong></button></div>
      <div class="camera-modes" role="tablist" aria-label="Capture mode"><button type="button" role="tab" data-capture-mode="photo" aria-selected="${!documentMode}" tabindex="${documentMode?-1:0}">Photo</button><button type="button" role="tab" data-capture-mode="document" aria-selected="${documentMode}" tabindex="${documentMode?0:-1}">Document</button></div>
      ${state.upload?`<button type="button" class="scan-selected-file" data-action="preview-upload">Selected: ${esc(state.upload.name)}</button>`:''}
    </div>
    <input type="file" id="photo-picker" accept="image/*" hidden><input type="file" id="camera-picker" accept="image/*" capture="environment" hidden><input type="file" id="file-picker" accept="image/*,application/pdf" hidden>
  </section>`;
}
