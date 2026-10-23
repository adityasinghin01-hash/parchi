# Checkout Assistant (A3a) — wiring notes
Mounted already: `Route.checkout` (ParchiApp.swift), `-demoRoute checkout`, and a button in `GetItAllView`.
- Settings: add `SignOutSellersRow()` (clears WKWebsiteDataStore; `CheckoutPrivacy.clearSellerSessions()` for code).
- Re-planning: `CheckoutFlow.onSkip` is a closure `(sellerID) -> Void`; set it where the flow is built in `CheckoutRouteView.onAppear`.
- Seller sites / lab pages: `Support/CheckoutAssistant/SellerSites.swift`. Order-confirm URLs: `engine/catalogue/seller_confirm_patterns.json` (empty on purpose).
- Debug: `-demoRoute checkout -checkoutScreen probe [-probeAuto 1]`, `-checkoutStep 2`.
