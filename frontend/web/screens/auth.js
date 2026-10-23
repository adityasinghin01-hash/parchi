import { icons } from '../components/icons.js';
import { glyph, brand, back, primary, divider, referenceArt, esc } from '../components/ui.js';

export function signinScreen(state) {
  return `<section class="screen auth-screen" aria-labelledby="signin-title">${back('welcome')}
    <div class="auth-hero">${brand()}${referenceArt('signin',[365,110,370,590],'auth-illustration')}
      <div class="auth-heading"><h1 id="signin-title">Let’s get you<br>started</h1><p>Sign in to save your parchis,<br>track orders and get reminders.</p></div>
    </div>
    <form class="phone-card" id="phone-form" novalidate><h2>Continue with phone number</h2><p>We’ll send you a one-time password (OTP)</p>
      <label class="number-field"><span class="dial-code">+91 ${glyph.chevronDown}</span><input name="phone" id="phone-number" type="tel" inputmode="tel" autocomplete="tel-national" maxlength="14" value="${esc(state.phone)}" placeholder="Enter your phone number" aria-label="Phone number" aria-describedby="phone-error" required></label>
      <p class="form-error" id="phone-error" role="status">${esc(state.error)}</p>
      <button type="submit" class="primary-action" ${state.busy?'disabled':''}>${state.busy?'Sending…':'Send OTP'} ${icons.arrow}</button>
    </form>
    ${divider}
    <button type="button" class="guest-card" data-action="guest"><span class="round-icon">${glyph.userFill}</span><span><strong>Continue as Guest</strong><small>Scan and use Parchi without an account</small></span><span class="chevron">${icons.chevron}</span></button>
    <div class="benefit-strip"><div><span>${glyph.document}</span><p>Save your<br>parchis</p></div><div><span>${icons.notifications}</span><p>Get medicine<br>reminders</p></div><div><span>${icons.usage}</span><p>Track orders<br>and tests</p></div></div>
    <p class="terms-note">By continuing, you agree to our<br><button type="button" data-info="terms">Terms of Service</button> · and · <button type="button" data-info="privacy">Privacy Policy</button></p>
  </section>`;
}

const letters={1:'',2:'ABC',3:'DEF',4:'GHI',5:'JKL',6:'MNO',7:'PQRS',8:'TUV',9:'WXYZ',0:''};
export function otpScreen(state) {
  const phone=state.challenge?.phone||state.phone.replace(/\s/g,'');
  const formatted=phone.length===10?phone.slice(0,5)+' '+phone.slice(5):phone;
  return `<section class="screen otp-screen" aria-labelledby="otp-title">${back('signin')}
    <div class="auth-hero">${brand()}${referenceArt('otp',[345,120,390,505],'otp-illustration')}
      <div class="auth-heading"><h1 id="otp-title">Verify your<br>phone number</h1><p>We’ve sent a 6-digit code to<br><strong>+91 ${esc(formatted)}</strong><button type="button" class="edit-phone" data-nav="signin">Edit</button></p></div>
    </div>
    <form id="otp-form" novalidate>
      <div class="otp-entry" id="otp-entry"><div class="otp-cells" aria-hidden="true">${Array.from({length:6},(_,index)=>`<span class="otp-cell ${index===state.otp.length?'is-active':''}">${state.otp[index]||'<i></i>'}</span>`).join('')}</div><input id="otp-code" name="otp" class="otp-input" inputmode="none" type="text" autocomplete="one-time-code" maxlength="6" pattern="[0-9]{6}" aria-label="Six-digit verification code" aria-describedby="otp-error otp-mode-note" value="${esc(state.otp)}"></div>
      <p class="form-error" id="otp-error" role="status">${esc(state.error)}</p>
      <div class="resend-row">Didn’t receive the code? <button type="button" data-action="resend" id="resend-button">Resend in <span id="resend-timer">00:30</span></button></div>
      <button class="primary-action verify-button" id="verify-button" type="submit" ${state.otp.length!==6||state.busy?'disabled':''}>${state.busy?'Verifying…':'Verify & Continue'} ${icons.arrow}</button>
    </form>
    <div class="numeric-keypad" aria-label="Verification code keypad">${[1,2,3,4,5,6,7,8,9,'',0,'erase'].map(key=>key===''?'<span></span>':key==='erase'?`<button class="erase-key" type="button" data-key="erase" aria-label="Delete last digit">${glyph.erase}</button>`:`<button type="button" data-key="${key}" aria-label="${key}"><strong>${key}</strong>${letters[key]?`<small>${letters[key]}</small>`:''}</button>`).join('')}</div>
    <p class="otp-mode-note" id="otp-mode-note">${state.challenge?.mode==='demo'?'Demo code: 482931 · No SMS is sent.':'Never share your code with anyone.'}</p>
  </section>`;
}
