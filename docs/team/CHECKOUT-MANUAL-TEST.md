# Checkout manual test (by hand, on the iMac Simulator or a phone)

Why by hand: the K21 probe (`app/KIRO_REPORT_K21.md`) only LOADS each seller's page and reads it. Nobody has yet logged in, added to cart, seen the cart total or reached the payment page inside Parchi's in-app browser. Parchi never clicks Add to cart, logs in or pays for you, and must not be changed to do so. This test is done by a person.

## HARD RULE
**STOP at the payment page. Never pay in a test.** No card, no UPI PIN, no "Place order", no "Pay now". If a page asks for a UPI approval, close it. If you tapped Pay by mistake, cancel the order in the seller's own app and write it down. Use your own account only. Do not test with someone else's phone number or address. Do not paste real OTPs, card numbers or passwords anywhere (not in notes, not in screenshots: crop them out).

## Set up (once)
1. Build and run Parchi (Xcode, scheme Parchi, iPhone 17 Pro Simulator, or your own iPhone). Needs internet.
2. Launch with the demo basket: Xcode Scheme > Arguments `-demoRoute getItAll`, or from Home read the demo parchi and go Confirm > Plan > Get it all.
3. Settings (Phase 4): note whether "Sign out of seller sites" is mounted. If it is not, delete the app between sellers to clear logins (the in-app browser keeps cookies).

## For EACH seller below
1. Plan > Get it all > "Open Checkout Assistant". Step through to the seller's step (steps run: online sellers, then labs, then local shops). The seller name is in the header.
2. The page opens in the in-app browser. Tap "Find on page" for the medicine in the strip at the top, check it is the right brand and strength.
3. **You** tap the seller's Add to cart / Add button. Then tap Parchi's "Added ✓".
   **Watch out (seen on Tata 1mg right after Add):** the seller may pop up "Switch to a cheaper generic". Tap **Not now**. Parchi never swaps your brand; only your doctor can approve a different one. Write down every such prompt you see (seller, wording).
4. Open the seller's cart yourself. **Screenshot 1: cart total and each line's price**. Write the Parchi plan price for the same item next to it (Plan screen) and the difference.
5. If the seller asks you to log in: log in with your own account (OTP to your own phone). **Screenshot 2: the login or OTP wall** (crop out your number). Write down: did it ask BEFORE the cart, or only at checkout? Could you continue as a guest (a "Continue as guest" / "Skip" link)? Yes / no.
6. If it asks for a pincode or location: enter your own pincode. Write down whether the price or stock changed after entering it.
7. Tap Parchi's "Go to checkout" (or use the seller's own Checkout button). Go forward until the **payment page** shows (address, slot, payment options). **Screenshot 3: the payment page. STOP HERE.** Do not choose a payment method. Press back.
8. Write down: anything that did not open (blank page, CAPTCHA, "Access denied"), anything that opened outside the app (UPI app, external browser, `upi://` link: Parchi blocks non-https links on purpose), and anything that looked wrong (wrong brand, wrong pack size, price higher than the plan).
9. Remove the item from the seller's cart and sign out, so the next test starts clean.

Seller list (use the order Parchi shows). "From the K21 probe" is what the page checks saw on page load; none of it shows what happens at the cart, login or payment.

| Seller | Opens at | From the K21 probe (read-only, 23 Oct 2026) | Special things to watch |
|---|---|---|---|
| Truemeds | product page | loads; "Add" and a price; a Login button; run 1 home page showed a "Choose your location / PIN code" sheet | pincode sheet before price; page may never "finish" loading |
| Tata 1mg | product page | renders but the load never finishes (40 s); "Buy now" / "ADD" and a price; no login or pincode wall at load | wait for the page; login often at cart |
| PharmEasy | home page only (no product link) | loads; price text; a pincode prompt text; no Add control on the home page | search the medicine yourself |
| Medkart | home page only | loads (thin page, 937 characters); pincode prompt text; no Add control | may be a landing page, not a shop |
| MedPlus | home page only | did not finish in 40 s on most runs; Login button; page mostly empty | most likely to stay blank; write down if it does |
| Netmeds | product page | 0 characters after 40 s on two of three runs; title read once ("Azithral 500mg Tablet 5'S"), page shown without styling | try the product page twice |
| Apollo Pharmacy | product page | loads fast; "Add to Cart", "Buy Now", a price, a pincode input | pincode input on the product page |
| Blinkit | product page | never finishes loading but renders; "Add to cart"; price; no login wall at load | needs a delivery location; quick-commerce stock varies |
| Swiggy Instamart | product page | loads; "ADD"; no price read | needs a location before it shows a price |
| Redcliffe Labs | home page | loads (20k characters); "Add To Cart"; price | labs: book a test, stop before payment |
| Healthians | home page | renders, never finishes; "Book Now"; price; pincode prompt text | pincode decides slots |
| Apollo Diagnostics | home page | renders, never finishes; "Add To Cart", "Book Walk-In Slots"; price | choose home collection, stop before payment |
| Max Lab | home page | run 1: a "Choose City" sheet and a Login link; run 2: nothing rendered | city sheet first |

## Guest checkout: what we know and what we do not
- The page checks cannot tell whether a seller allows guest checkout. They only saw the product or home page on load.
- On load, no login wall was seen on the product pages of Truemeds (run 2), Tata 1mg, Apollo Pharmacy, Blinkit and Instamart. That does NOT mean guest checkout: most of these ask for a mobile number and an OTP at the cart or checkout step. Treat all of them as "login needed" until step 5 above says otherwise.
- Max Lab and Truemeds showed a city or PIN code sheet on the home page before anything else. Netmeds, MedPlus: not loaded well enough to say.
- Write the real answer for each seller in the table below after your test.

## Result sheet (copy per run)
| Seller | Date/time | Cart total vs Parchi plan price | Login/OTP/pincode wall (when?) | Guest possible? | Reached payment page? (screenshot name) | Problems |
|---|---|---|---|---|---|---|
| | | | | | | |

Keep the screenshots out of git (they can show your address). Send only the table to the team.
