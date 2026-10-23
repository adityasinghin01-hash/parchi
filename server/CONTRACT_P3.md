# Phase 3 API contract: shop ask (A3) + lab booking (A5). Server (S2a) and app (A3b) BOTH build to this. Claude owns changes.
Auth: app endpoints use header `X-Install-Key` (same as /order); shop/lab REPLY pages use an unguessable per-shop/per-lab token in the URL (no key, URL is the secret, 22+ char urlsafe token); judge endpoints use `X-Admin-Key`. Money = integer paise. Times = ISO-8601 with offset (IST +05:30). All responses JSON except the reply pages (HTML). Sandbox rows are labelled "Test" only if created via /judge.
Base URL examples: `http://<iMac-LAN-ip>:8000`.

## Shop ask
- `POST /shop/ask` {items:[{itemID,name,strength?,quantity}], shops:[{shopID,name,phone?,distanceM?}] (1..9, nearest first), pickupBy: ISO time, groupSize?:3, waitMinutes?:10, orderID?:string} -> 201 {askID, round:1, replyLinks:[{shopID,url}]} (links only for the FIRST group; the user's phone puts the link in its WhatsApp message and presses send; the server never sends messages).
- `GET /shop/{askID}/status` -> {askID, state:"waiting|replied|closed", round, noReply:bool, nextGroup:[shopID], shops:[{shopID, state:"asked|replied|not_needed|no_reply|not_asked", askedAt?, repliedAt?, items:[{itemID, available:bool, pricePaise? = price for the WHOLE quantity asked (planner Offer.price semantics)}], totalPaise?, readyBy?}], winnerShopID?}
- `POST /shop/{askID}/next` -> 200 {round, replyLinks:[...]} opens the next group of shops (no reply within waitMinutes -> status.noReply=true and nextGroup is filled; the user taps once). 409 if nothing to open.
- `GET /shop/reply/{token}` -> one-page mobile HTML (English + Hindi labels, big touch targets, no JS framework, <20 KB): item list, per item "Available / Not available" + price per pack in rupees + "Ready by" time + Send. `POST /shop/reply/{token}` (form or JSON) stores the reply; the FIRST complete reply (all items answered) wins; other shops' pages then show "Thanks, this is no longer needed" and their state becomes not_needed. A shop may answer only once.
- Judge: `POST /judge/shop/{askID}/reply` {shopID, items:[{itemID,available,pricePaise?}], readyBy} (admin) simulates a reply.
## Lab booking
- `POST /lab/book` {labID, labName, tests:[{testID,name,fasting?:bool}], homeCollection:bool, preferredSlot: ISO time, addressText?, orderID?, sellerID?} -> 201 {bookingID, replyLink}
- `GET /lab/{bookingID}/status` -> {bookingID, state:"requested|confirmed|rejected|collected|report_due|report_chase_due|done", noReply:bool, slot?, feePaise?, reportDueAt?, fastingReminderAt? (21:00 IST the evening before slot, only if any test fasting:true), note?}
- `GET/POST /lab/reply/{token}` -> HTML: Confirm this slot / Propose another slot (+fee) / Cannot do.
- Judge: `POST /judge/lab/{bookingID}/event` {kind:"confirmed|collected|report_ready|sample_rejected|phlebotomist_late"} (admin). If the booking carries orderID+sellerID, sample_rejected / phlebotomist_late ALSO signal the order workflow: `seller_event(sellerID,"sampleRejected"|"late")` so Plan B runs.
## Timers (Temporal; workflow input has time_scale like OrderWorkflow so tests use time skipping)
Shop: no complete reply within waitMinutes -> noReply. Lab: no reply in 30 min -> noReply; report chase = reportDueAt + 6 h -> state report_chase_due.
## Shared rules
No medical advice anywhere; no brand swapping ("exact brand and strength as written"); never store patient name or phone.
