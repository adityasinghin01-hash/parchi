import { icons, decoration } from '../components/icons.js';

// Content is kept separate from layout for the later SwiftUI implementation.
export const permissions = [
  { id: 'location', title: 'Location', description: 'Find nearby pharmacies and labs<br>and show accurate prices', detail: 'Use your area to find nearby pharmacies and labs. You can choose an area manually when you need it.' },
  { id: 'camera', title: 'Camera & Photos', description: 'Scan your prescription from camera,<br>photos or WhatsApp', detail: 'Choose how you want to share a prescription. Camera and photo access will be managed separately in the iOS app.' },
  { id: 'notifications', title: 'Notifications', description: 'Reminders for medicines, tests<br>and important updates', detail: 'Choose whether to receive reminders for medicines, tests and important updates. You can continue with reminders off.' },
  { id: 'usage', title: 'Usage Data (optional)', description: 'Helps us improve accuracy<br>and experiences', detail: 'Choose whether you want to help improve the Parchi experience. This preference is optional and does not affect guest access.' }
];

export function permissionRow(permission) {
  return `<button type="button" class="permission-row" data-permission="${permission.id}" aria-haspopup="dialog"><span class="permission-row__icon">${icons[permission.id]}</span><span class="permission-row__copy"><span class="permission-row__title">${permission.title}</span><span class="permission-row__description">${permission.description}</span></span><span class="permission-row__chevron">${icons.chevron}</span></button>`;
}

export function welcomeScreen() {
  return `<section class="welcome" aria-labelledby="welcome-title">${decoration}
    <div class="welcome__brand"><img class="welcome__logo" src="assets/parchi-logo-transparent.png" alt=""><div class="welcome__wordmark" aria-label="Parchi">Parchi</div><p class="welcome__tagline">YOUR HEALTH, MORE CLEARLY</p></div>
    <h1 class="welcome__headline" id="welcome-title">Turn your prescription<br>into a <em>clear plan</em></h1>
    <p class="welcome__intro">Parchi reads your prescription, protects your privacy,<br class="reference-break"> shows options and helps you get your medicines easily.</p>
    <div class="welcome__permissions" aria-label="Permissions and preferences">${permissions.map(permissionRow).join('')}</div>
    <section class="privacy-panel" aria-labelledby="privacy-title"><span class="privacy-panel__icon">${icons.shield}</span><div><h2 id="privacy-title">Your privacy is our priority</h2><p>We automatically blur sensitive details like<br class="reference-break"> your name, age and phone number.</p></div></section>
    <div class="welcome__actions"><button type="button" class="primary-action" data-continue="agree">I Agree &amp; Continue ${icons.arrow}</button><button type="button" class="text-action" data-continue="guest">Continue as Guest</button></div>
  </section>`;
}
