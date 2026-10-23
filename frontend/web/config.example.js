// Optional. Load a real configuration BEFORE web/app.js in index.html.
// Do not commit credentials. These routes must be mapped to the team's actual API.
// window.PARCHI_CONFIG = {
//   mode: 'backend',
//   baseUrl: 'https://your-backend.example/frontend-api/',
//   tokenProvider: () => null,
// };
// A map integration is independent of the API. It is OFF by default.
// window.PARCHI_MAP_PROVIDER = {
//   mount(element, {area, onSelect, onStatus}) {
//     // Mount your chosen map SDK here, after required consent/key configuration.
//     // Render only real coordinates and prices. Return an Area via onSelect(area).
//     onStatus({state:'unavailable', message:'Map unavailable'});
//     return () => {}; // Remove listeners, requests and map instance on navigation.
//   }
// };
