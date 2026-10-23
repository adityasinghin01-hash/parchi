# Phase 7: Legal + cost per user (23 Oct 2026, ~12:30 IST)
Labels: **[M]** measured · **[V]** checked in a source · **[J]** judgement · **[A]** assumption.

## 1. Rules that apply, and what each forces in the design
| Rule | What it says | Status | Parchi design rule it forces |
|---|---|---|---|
| **Drugs Rules 1945, Schedule H** | Sold only against a registered doctor's prescription, only the quantity prescribed; "Rx" on the label [V] | In force | Never sells. Shows only the prescribed quantity, never "buy more" |
| **Schedule H1** (G.S.R. 588(E), 30 Aug 2013, in force 1 Mar 2014, 46 entries) | Red-box warning; **chemist keeps a copy of the prescription and a separate register**. Covers 11 psychotropics, 3rd/4th-gen antibiotics, TB drugs (alprazolam, zolpidem, tramadol, codeine, levofloxacin…). Now ≥52 entries; pregabalin added by G.S.R. 377(E), 13 May 2026, in force 180 days after publication [V, secondary sources] | In force | H1 items get a badge: **"Buy at a chemist with the original parchi"** |
| **Schedule X** | Narcotic/psychotropic; chemist **keeps** the prescription; "XRx" label [V] | In force | **No online hand-off ever.** In person only |
| **Draft e-pharmacy rules** (G.S.R. 817(E), 28 Aug 2018) | E-pharmacies may not sell NDPS narcotics/psychotropics, tranquilizers, Schedule X [V] | **Still not notified** (2026 paper, phase 7 start) | Same as above. Parchi only routes to **licensed** sellers (Madras HC, Jul 2024) |
| Draft Rule 65 change (2026) | Retailers may not advertise Schedule H/H1/X medicines without government sanction [V, secondary] | Draft | Parchi never promotes a medicine. It shows only what the doctor wrote |
| **CCI market study** (already in file 04) | Chemist brand substitution is unlawful [V] | — | **No substitution.** Jan Aushadhi/same-salt = price information + "ask your doctor" |
| **Consumer Protection (E-Commerce) Rules 2020, Rule 5(3)(f)** | A marketplace must explain the **main ranking parameters** in plain language [V, Lok Sabha answer] | In force | If Parchi earns affiliate commission it is likely an e-commerce entity [J]. A public "How we rank" page |
| **E-Commerce (Amendment) Rules 2026** (G.S.R. 789(E), 9 Sep 2026, **in force 1 Jan 2027**) | Ranking now covers sellers too, "irrespective of the technological means"; **sponsored listings must be labelled** (Rule 4(12)); no misleading search manipulation; dark-pattern compliance with a **yearly self-audit** and a displayed certificate [V: Bar & Bench, S.S. Rana, IndiaLaw] | Notified | "Why this plan?" + "How we rank: 1 total cost to complete, 2 ready time, 3 trips. No seller pays for position." No sponsored slots in v1 |
| **Dark Patterns Guidelines 2023** (CCPA, 30 Nov 2023) | **Drip pricing** banned: hiding the full price and revealing cost parts at different stages [V] | In force | **Cost to Complete is the anti-drip feature.** Phase 5 found sellers' fees are shown only at checkout [M] |
| **Telemedicine Practice Guidelines 2020** | Apply to doctors consulting remotely and platforms that connect them. When a doctor sends a prescription to a pharmacy, the patient must be free to **use any pharmacy** [V] | In force | Parchi doesn't consult or prescribe → **not covered**. The "any pharmacy" principle supports our neutral ranking |
| **IMC Regulations 2002, 6.4** (NMC 2023 rules held in abeyance Aug 2023; 2002 rules apply) | Commission for referring patients, **including diagnostic specimens**, is unethical [V] | In force (no later change found) | Supports the problem slide (choice, not accusation). **Keep it non-adversarial**: Parchi gives the patient options; it doesn't accuse doctors |
| **CDSCO Medical Device Software guidance** (CDSCO/MD/GD/MDSW/01/2026, 21 Jul 2026, 62 pp) | Software is a medical device only if **intended for a medical purpose**. Section 5.2 lists **not covered**: software that does "transfer, storage, archive data, **convert, format, communication, simple search**"; systems for "**scheduling**… billing"; communication systems that send "**prescription**, referrals" [V, official PDF; excerpt saved] | Guidance in force | Parchi = read, convert, compare price, order, schedule → **not medical device software** [J, based on 5.2]. Section 6 lists "recommended treatment", "**recommended additional tests**", "prescription" as medical outputs → **we never add those** |
| **DPDP Act 2023 + Rules 2025** | Covered in file 03 | In force | Consent, blur, deletion, breach reporting |

### Lines Parchi must never cross (to stay out of medical-device and pharmacy rules)
1. No dose checking, no interaction alerts, no "you should take" advice. The Brand–Strength Check is worded **"This product is sold as 20 / 40 / 80 mg"**, never "this dose is safe".
2. No recommending tests or treatments. Tests come only from the parchi.
3. No substitution. Generic savings are shown as price facts plus "only your doctor can approve a switch".
4. No sale, no dispensing, no money held. Sellers are licensed and do their own prescription check.
5. H1 / X / narcotics: in person only, with the original parchi.
6. No disease-management claims (CDSCO Example 10: chronic-disease coaching platforms **are** medical devices).

## 2. Cost per user
**Hackathon: ₹0.** The model runs on the lab iMac, Apple Maps is free, and there's no paid API.

**After the hackathon, if run on a rented GPU** (₹95.95 per $):
| Item | Number | Basis |
|---|---|---|
| GPU | NVIDIA L4 24 GB, **$0.44/h**, billed per minute | [V] jarvislabs.ai/pricing, 23 Oct |
| Time per handwritten parchi | **10 s** | **[A]**, replaced by the Kaggle measurement in step (d) |
| Printed parchis | Read on the phone: **₹0** | [M] Apple Vision ≥80% on printed |
| **Cost per handwritten scan** | $0.44 × 10/3600 = $0.00122 = **₹0.12** | Calculated |
| Scans per user per month | 2 | [A] family use |
| **Variable cost per user per month** | **≈ ₹0.23** | Calculated |
| GPU always on | $0.44 × 730 h = $321 = **₹30,800 a month** | Calculated |
| Users needed so fixed cost is ≤ ₹5/user/month | ≈ **6,200** | Calculated |
| Maps (on-phone MapKit search) | ₹0, no published quota; ~50 searches/min throttle reported | [V, forum] |
| Shop Quote by WhatsApp Cloud API (roadmap) | ₹0.115–0.35 per utility message | [V, earlier] |
| Storage | $0.10/GB-month; a blurred crop is ~0.1 MB | [V] |
| Paid Apple Developer Program | ₹8,700/yr (only to publish) | [V, forum] |

**Revenue side, for scale only:** affiliate commission up to ₹150 per 1mg order (EarnKaro page, undated) [V, weak]. One order a month from 2% of users covers the fixed GPU cost at about 10,000 users [J].

Sources: Schedule H/H1/X https://www.gktoday.in/schedule-h-schedule-x-and-schedule-h1-drugs/ · https://en.wikipedia.org/wiki/Schedule_H · https://www.civilsdaily.com/news/drugs-rules-1945-tighter-regulation-of-schedule-h-h1-and-x-drugs/ · H1 additions https://accountune.com/pharmacy-billing-batch-expiry-guide · Draft e-pharmacy https://mondaq.com/india/food-and-drugs-law/747792/centre-proposes-draft-e-pharmacy-rules-to-regulate-online-sale-of-drugs · E-Commerce Rules 2020 Lok Sabha https://fcainfoweb.nic.in/PMS/writereaddata/2021_LS_B_73.pdf · 2026 amendment https://www.barandbench.com/law-firms/view-point/consumer-protection-e-commerce-amendment-rules-2026-from-consumer-disclosure-to-platform-governance · https://www.indialaw.in/blog/consumer/consumer-protection-e-commerce-amendment-rules-2026/ · Dark patterns https://www.jsalaw.com/newsletters-and-updates/ccpa-issues-guidelines-for-prevention-and-regulation-of-dark-patterns-2023/ · Telemedicine https://www.medianama.com/2020/03/223-summary-india-telemedicine-guidelines/ · IMC 6.4 https://rsdebate.nic.in/bitstream/123456789/680487/2/PQ_244_02012018_U1702_p269_p270.pdf · NMC 2023 abeyance https://www.siasat.com/regulations-mandating-doctors-to-prescribe-generic-drugs-put-on-hold-2676559/ · CDSCO MDSW https://www.cdsco.gov.in/opencms/export/sites/CDSCO_WEB/Pdf-documents/Guidance-document-on-Medical-Device-Software-under-MDR-2017.pdf (excerpt: phase7-legal/cdsco_mdsw_excerpts.txt) · Jarvis https://jarvislabs.ai/pricing · MapKit throttle https://developer.apple.com/forums/thread/760867
