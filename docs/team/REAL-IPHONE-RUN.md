# T10: run Parchi on a real iPhone against the lab iMac server (checklist for Aditya Singh + one teammate's iPhone)
No iPhone is connected to the iMac right now (`xctrace` lists only the iMac and simulators), so this step needs a person. Free Apple account only: the app is signed with a **Personal Team** and expires after 7 days (fine for the demo; install the night before).

## One-time setup on the iMac (Xcode 26.2)
1. Xcode > Settings > Accounts: add the teammate's Apple ID (or yours). Plug the iPhone in by cable, unlock it, tap **Trust**.
2. On the iPhone: Settings > Privacy & Security > **Developer Mode** on (restarts the phone). 
3. `cd ~/parchi/app && xcodegen generate && open Parchi.xcodeproj`. Target **Parchi** > Signing & Capabilities: Team = Personal Team. If Xcode says the bundle id is taken, change `PRODUCT_BUNDLE_IDENTIFIER` in `app/project.yml` to something unique (for example `in.tessanova.parchi.<yourname>`), run `xcodegen generate` again.
4. Select the iPhone as the run destination and press Run. First launch: on the phone, Settings > General > VPN & Device Management > trust the developer profile.

## Point the phone at the server
- iMac addresses (23 Oct): Ethernet/Wi-Fi `10.21.70.73` (en0) or `10.110.220.139` (en1). The phone must be on the **same Wi-Fi/subnet**; if the college network isolates devices, use a phone hotspot for both (the iMac joins the hotspot) or ask the lab admin.
- The server already listens on `0.0.0.0:8000` (`server/run.sh`). Check from the phone's Safari: `http://<iMac-ip>:8000/health` should show `{"ok":true,"temporal":true}`.
- In the app, Home > Developer: **Live**, URL `http://<iMac-ip>:8000`, install key (from `~/parchi/server/data/sim_install.key` on the iMac; send it by AirDrop/note, never commit it). Tap **Test connection**. Allow the **Local Network** prompt.
- Shop and lab reply links open on any phone browser at `http://<iMac-ip>:8000/shop/reply/<token>`; set `PARCHI_PUBLIC_URL=http://<iMac-ip>:8000` before `bash run.sh` so the links the app builds use the right address.

## What to test on the phone (the Simulator cannot do these)
| Check | Pass |
|---|---|
| Document scanner / Photos import / WhatsApp share (Capture, when built) | a parchi image reaches Confirm |
| SMS composer (Checkout Assistant local-shop step, lab request) | message sheet opens with the text filled |
| WhatsApp deep link (Ask nearby shops) | WhatsApp opens with the message and reply link |
| Location permission + map centre on you; deny it and the city picker appears | both paths work |
| Calendar write-only permission + lab slot added; fasting reminder fires | event exists; notification arrives |
| Judge cancel from `http://<iMac-ip>:8000/judge` (log in with the admin key once; no key in the URL) | Plan B sheet appears on the phone in about 2 s |
Record each row as pass/fail with a screenshot in `docs/verification/`.
