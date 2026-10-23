# Parchi usability test kit (SUS) — run on build day or with the prototype
**Goal:** a measured UI/UX score. "If built" UX = 9.0 only when **SUS ≥ 80** with 5–8 people. Industry average SUS = 68 (Lewis 2018).

## Who (5–8 people)
- At least **1 person aged 60+** and **1 Hindi-first** user.
- At least 2 who have bought medicines for a parent in the last 3 months.
- Not on our team. Note age group and phone comfort (low / medium / high) only. No names in the sheet.

## Consent (read aloud, 20 s)
"We're testing an app, not you. It uses a sample prescription, not yours. We'll time a few tasks and ask 10 quick questions. You can stop anytime. We won't record your face or name."

## Setup
- Demo phone or Simulator with the demo parchi in WhatsApp; Demo reset done.
- One observer times with a stopwatch and counts taps; nobody helps unless asked (that counts as "help").

## Tasks (same order for everyone)
| # | Task (say exactly this) | Success = | Record |
|---|---|---|---|
| T1 | "Your doctor's parchi is in WhatsApp. Get it into Parchi and check the medicines are right." | List confirmed, flagged line fixed | time, taps, errors, help Y/N |
| T2 | "Get everything on it, as cheap as possible." | Cheapest plan chosen, "Get it all" pressed | time, taps, errors, help |
| T3 | "One shop just cancelled. Sort it out." | Plan B approved | time, taps, help |
| T4 | "Show the chemist what you need." | Parchi Pass opened | time, taps, help |

**Comparison (optional, same person, after):** do T1+T2 for medicines only on QuickPill, and for tests on LabFare. Record time and taps.

## SUS questionnaire (after the tasks), 1 = strongly disagree … 5 = strongly agree
Standard SUS items (Brooke 1996). The Hindi lines are **our translation, not a validated Hindi SUS**; say so in the report.
| # | English | हिंदी |
|---|---|---|
| 1 | I think that I would like to use this system frequently. | मुझे लगता है कि मैं इस ऐप को बार-बार इस्तेमाल करना चाहूँगा/चाहूँगी। |
| 2 | I found the system unnecessarily complex. | मुझे यह ऐप बेवजह मुश्किल लगा। |
| 3 | I thought the system was easy to use. | मुझे यह ऐप इस्तेमाल करने में आसान लगा। |
| 4 | I think that I would need the support of a technical person to be able to use this system. | मुझे लगता है कि इसे चलाने के लिए मुझे किसी तकनीकी व्यक्ति की मदद चाहिए होगी। |
| 5 | I found the various functions in this system were well integrated. | इस ऐप के अलग-अलग हिस्से अच्छी तरह आपस में जुड़े हुए लगे। |
| 6 | I thought there was too much inconsistency in this system. | मुझे इस ऐप में बहुत ज़्यादा असंगतता (बातें आपस में मेल नहीं खातीं) लगी। |
| 7 | I would imagine that most people would learn to use this system very quickly. | मुझे लगता है ज़्यादातर लोग इसे बहुत जल्दी चलाना सीख जाएँगे। |
| 8 | I found the system very cumbersome to use. | मुझे यह ऐप चलाना बहुत झंझट भरा लगा। |
| 9 | I felt very confident using the system. | इसे इस्तेमाल करते हुए मुझे पूरा भरोसा था। |
| 10 | I needed to learn a lot of things before I could get going with this system. | इसे चलाने से पहले मुझे बहुत कुछ सीखना पड़ा। |

## Sheet (one row per person) → `sus_results.csv`
`pid,age_group,hindi_first,T1_s,T1_taps,T1_ok,T1_help,T2_s,T2_taps,T2_ok,T2_help,T3_s,T3_taps,T3_ok,T3_help,T4_s,T4_taps,T4_ok,T4_help,q1,q2,q3,q4,q5,q6,q7,q8,q9,q10,comment`

## Scoring
`python3 sus_score.py sus_results.csv`. Per person: odd items (score − 1), even items (5 − score), sum × 2.5. It prints the mean, median and 95% interval (t-based), task success, and median time and taps.

## How we report it
"SUS **X** (n = N, 95% CI a–b), task success **Y%**, median **Z taps** to order the whole parchi vs **W taps** for medicines only on QuickPill." Small samples are noisy, so we always give n and the interval.
