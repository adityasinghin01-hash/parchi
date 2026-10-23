# Parchi browser frontend integration

## Current routes and implementation

The app is a modular HTML/CSS/JavaScript iPhone design prototype. The five new routes follow the five supplied images; the earlier welcome screen is retained.

| Route | UI and interactions |
|---|---|
| `#/welcome` | Permission preview sheets; agree opens sign-in; guest opens Home. |
| `#/signin` | Phone entry, required ten-digit Indian mobile validation, Send OTP, guest entry, terms/privacy preview dialogs. |
| `#/verify` | Six-cell accessible input, paste/keyboard support, working numeric keypad/delete, explicit verification, incorrect/expired/rate-limit states and 30-second resend cooldown. |
| `#/home` | Location, sample order and recent parchis, search filtering, scan/import shortcuts, five-tab navigation. Tabs without supplied full-screen references open clearly scoped detail dialogs. |
| `#/area` | Unavailable map placeholder; saved/recent areas, radio selection, area search/manual entry, city tiles, manage/clear and confirmation. Confirm updates Home. |
| `#/capture` | Native-browser file/camera entry, image/PDF selection, local preview, manual item list and reference sample thumbnails. No OCR or upload. |

The default adapter is a **demo**. OTP is `482931`, taken from the reference artwork, and no SMS is sent. User-entered phone/code and selected files remain in page memory. Orders, dates, names, service labels and saved areas are reference fixtures, not real activity or verified local coverage. No third-party requests occur in the default preview.

## Modular design

- `web/styles/tokens.css`: shared palette, fonts, corner/motion/touch tokens.
- `web/styles/components.css`: shared base controls and preview shell.
- `web/styles/screens.css`: new reference layouts, scaled from a 735-unit source artboard.
- `web/components/ui.js`: brand, search, tabs, common controls and artwork-region helper.
- `web/components/icons.js`: reusable icons and the original welcome decoration.
- `web/screens/`: semantic screen templates; dynamic data is escaped.
- `web/services/fixtures.js`: reference-only records.
- `web/services/api.js`: demo adapter and replaceable backend adapter.
- `web/services/map.js`: independent map-provider boundary, unavailable by default.
- `web/app.js`: routing, interactions, transient state and integration events.

The supplied JPEGs are preserved under `assets/references/`. Only decorative illustration regions are reused in SVG viewports: hand/phone/receipt art, the courier, city artwork and sample document thumbnails. Screen text, inputs, cards, buttons, keyboard, status, tabs and layout are implemented as live HTML/CSS; a full-screen screenshot is not used as the interface. The original/transparent logo files are retained unchanged.

## Backend contract

The endpoint names below are **proposed frontend contract routes**, not a claim that they match the team's deployed backend. The integration owner maps them in `createBackendAdapter` to the agreed API and supplies the correct base URL/auth. There are no embedded credentials.

Load configuration **before** `web/app.js`, using `web/config.example.js` as a guide:

```js
window.PARCHI_CONFIG = {
  mode: 'backend',
  baseUrl: 'https://your-backend.example/api/',
  tokenProvider: () => null // Supply a token through your approved session layer.
};
```

| Adapter method | Proposed route | Required response |
|---|---|---|
| `startOtp(phone)` | POST `auth/otp/start` | `{id,phone,expiresAt,resendAt}`; timestamps are epoch milliseconds. |
| `verifyOtp(id,code)` | POST `auth/otp/verify` | Auth/profile result from the real service. Production session handling belongs to the integration layer. |
| `getHome({signal})` | GET `frontend/home` | `{area,serviceLabel,activeOrder,recent,source}` using the documented fixture shape. |
| `getAreas({signal})` | GET `frontend/areas` | `{saved:Area[],recent:Area[]}`. |
| `searchAreas(query,{signal})` | POST `frontend/areas/search` | `Area[]`. |
| `confirmArea(area)` | POST `frontend/areas/confirm` | Confirmed `Area`. |
| `resolveLocation(coordinates)` | POST `frontend/areas/resolve` | Actual resolved `Area`; never infer a place from unknown coordinates. |

`Area`: `{id,label,detail?,city?,icon?,coordinate?:{latitude,longitude}}`. Unknown availability, stock, fee or price should remain unknown in future response extensions. Errors may return `{code,message}` with non-2xx status. HTTPS, access control, CORS and session storage must be handled by the actual application integration.

## Map integration

The default map deliberately shows **Map unavailable**. No map tiles, SDK, location tracking, API key or map screenshot is loaded. Current-location lookup also stays unavailable in demo mode; manual selection works.

To integrate later, provide this object before the app module:

```js
window.PARCHI_MAP_PROVIDER = {
  mount(element, {area, onSelect, onStatus}) {
    // Mount the selected map SDK using the real area/coordinates.
    // onSelect(confirmedArea) updates the area draft.
    // onStatus({state:'loading'|'ready'|'unavailable'|'error', message?})
    return () => {
      // Remove provider listeners, requests and the map instance.
    };
  }
};
```

The provider owns actual map rendering, attribution and permission/key requirements. Backend place/price data and client map rendering are independent. The browser only requests device geolocation after an explicit tap and only in backend mode; denial/error offers manual entry. Entering the area page never requests device access.

## Integration events

- `parchi:welcome-complete`: `{choice,preferences}`.
- `parchi:area-selected`: confirmed Area.
- `parchi:capture-selected`: `{file,source:'local-file'}` or `{items,source:'manual'}`.

File events carry a real in-memory File object, not an uploaded URL. Do not connect a real processing/upload service until the user-facing privacy promises, review and protection flow are implemented. The current privacy copy is retained from the supplied design but is not proof of an OCR/redaction system. No real scan results or medical recommendations are fabricated.

## Verification performed

Browser checks on the local preview covered invalid phones, incomplete and incorrect OTPs, keypad and delete, resend cooldown, correct demo verification, guest routing, the fixed Home tab bar, manual area fallback, area confirmation, local image preview, manual test entry, and Home's Photos shortcut. All six routes were checked at 320px without horizontal overflow. JavaScript module syntax checks passed; no JavaScript errors or third-party requests were observed in the default flow. A mock map-provider mount/cleanup and injected backend request contract were exercised without contacting external services.

These checks do not establish a real OTP delivery service, live map, order tracking, OCR or native iOS functionality. The preserved Swift source is not updated by this browser work; it will be rewritten after design approval.
