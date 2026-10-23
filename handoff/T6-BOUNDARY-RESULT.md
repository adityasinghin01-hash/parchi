# T6 "push the Checkout Assistant to the boundary": what was run and what it showed (24 Oct 2026, ~05:30 IST)
STATUS: **T6 is still NOT MET.** This is a guest probe from a desktop browser, not the in-app browser, and not a person. It maps where a guest is stopped; it does not prove the in-app flow. Nobody logged in, nothing was entered except nothing (no pincode, phone, address or payment detail), nothing was bought, and every session's cookies were cleared afterwards.

## Method (so it can be repeated or challenged)
Playwright Chromium, viewport 390x844, fresh cookies per seller, one product page per seller (links from `engine/catalogue/product_links.json`), human-paced, one pass. Clicked only a visible "Add"/"Add to cart" control and a "Not now" dismiss. Never clicked anything labelled Buy now, Pay, Place order or Confirm. Signals are text matches on the page (login words, pincode/location prompts, price symbol, "cart is empty"), so they are hints, not proof. Screenshots are in the session scratchpad only (they can show a real cart).
NOT probed, with reasons: **PharmEasy** (its terms ban automated access; also home page only), **Medkart, MedPlus** (no product link, pages unreliable), **Blinkit, Swiggy Instamart** (need a delivery location first; app-like pages), the 4 lab sites (booking flows; a person should do them).

## Results
| Seller | Product page | "Add" as a guest | Cart / next step as a guest | Notes |
|---|---|---|---|---|
| Tata 1mg | opens, price shown, no login or pincode wall | Add click works | no cart control found by the probe; cart not reached | **After Add, a "22% savings with generic alternative: Switch / Not now" prompt appears** (see finding below) |
| Truemeds | opens, price shown; login words on page | Add click works | opening /cart sent the guest back to the home page with a pincode/location prompt | needs a pincode before a cart exists |
| Netmeds | opens, price shown | no Add control found by the probe (may need pincode, or a different button) | `/cart/bag/` opens as a guest and is empty (nothing was added) | try by hand |
| Apollo Pharmacy | opens; price not detected in text; login words | Add click works | the cart address I guessed (`/cart`) is a 404; real cart address unknown | try by hand |
Nothing reached an address, slot or payment page by automation. The login wall was never seen BEFORE Add on the four pages above; where it appears after Add is untested.

## Finding that matters for Parchi's rules (logged as B002, P1)
Inside a seller's own page, the seller can offer a different brand ("Switch to generic"). Parchi never swaps a brand; only the doctor can approve a substitute. The Checkout Assistant shows the seller's page unchanged, so a patient can tap "Switch" by accident or because it looks like Parchi's advice. Needed: a visible reminder in the Checkout Assistant ("If the seller offers a different brand, tap Not now. Parchi never swaps your brand; ask your doctor first."), and the manual test below now tells testers to watch for it.

## What a person must do (boundary = payment page, never pay)
Follow `docs/team/CHECKOUT-MANUAL-TEST.md` on the real iPhone or the simulator for each seller, with your own login (OTP to your own phone). Record the three screenshots it asks for and, per seller, which wall came first: pincode, login, or neither. That is what turns T6 from NOT MET to measured. PharmEasy, Medkart, MedPlus, Blinkit, Instamart and the labs can only be done this way.
