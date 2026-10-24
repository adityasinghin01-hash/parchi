# Module A — measured results

Command (from teammates/aditya-helpers): `python -m pytest problem-helper/tests -q`

Runtime: 3.11.16; pytest pinned in ../requirements.txt.

```text
........................................................................ [ 48%]
........................................................................ [ 97%]
...                                                                      [100%]
147 passed in 0.99s
```

Six fixed golden cases below were inspected for message facts, contacts, date calculations, local-shop and sandbox exclusions. Tests compare subsequent output against these committed files. Hindi remains unreviewed by a native speaker. API-level demo checks cover page delivery, 24-company list, generation, cross-origin rejection and invalid input; A browser check also generated a synthetic Hindi wrong-item complaint for Blinkit and verified visible message, sourced escalation and planned dates; no message was sent.

Review fixes: validate object shapes; use UTF-8 for the Windows CLI; do not infer that a whole order amount equals the disputed refund; distinguish planned follow-ups from a sent complaint. No independent legal or contact freshness verification performed.

## missing_local
```json
{
  "input": {
    "lang": "en",
    "issue": "missing_item",
    "seller": {
      "name": "Example local shop",
      "kind": "local_shop"
    },
    "order": {
      "orderId": "EXAMPLE-001",
      "placedOn": "2026-10-20",
      "amountPaise": 269677,
      "paidVia": "upi",
      "items": [
        {
          "name": "Dolo",
          "strength": "650",
          "qty": 15
        }
      ],
      "isTestOrder": false
    },
    "events": {
      "refundRequestedOn": "2026-10-22",
      "supportContactedOn": "2026-10-28"
    },
    "today": "2026-10-30"
  },
  "output": {
    "message": {
      "subject": "Order support request — EXAMPLE-001",
      "body": "Hello,\nAn item is missing from my order.\nOrder ID: EXAMPLE-001\nPlaced on: 2026-10-20\nAmount: ₹2696.77\nPayment method: upi\nItems: Dolo / 650 / qty 15\nRefund requested on: 2026-10-22\nSupport contacted on: 2026-10-28\nPlease send the missing item or refund its cost.\nThank you.",
      "lang": "en"
    },
    "evidence": [
      "Order confirmation and bill",
      "Payment record, if paid",
      "Support conversation, if available",
      "Record of the received items"
    ],
    "ladder": [
      {
        "level": 1,
        "who": "Seller support",
        "how": "Use the seller's email or order app chat",
        "contact": null,
        "when": "now",
        "why": "Ask the seller first"
      },
      {
        "level": 3,
        "who": "National Consumer Helpline (NCH)",
        "how": "1915 / WhatsApp 8800001915 / https://consumerhelpline.gov.in",
        "contact": {
          "value": "1915",
          "sourceUrl": "https://newsonair.gov.in/toll-free-number-in-17-languages-for-consumers-grievance-redressal-across-the-country-govt-in-ls/",
          "dateSeen": "2026-10-24"
        },
        "when": "now",
        "why": "You can ask the helpline about next options; check on the official site"
      }
    ],
    "followUps": [],
    "notes": [
      "Message is a draft for you to review and send.",
      "SECONDARY SOURCES ONLY (news and law-firm notes). Every item must be checked on the official page and re-dated before the app shows it to a patient. Until then the app must label it 'check on the official site'.",
      "check on the official site",
      "Refund completion time is not verified; no number is promised.",
      "we could not find a contact for this company"
    ],
    "disclaimer": "Review and send this message yourself. Parchi does not send messages, handle money or provide legal advice.",
    "precautions": []
  }
}
```

## refund_en
```json
{
  "input": {
    "lang": "en",
    "issue": "refund_pending",
    "seller": {
      "name": "Tata 1mg",
      "kind": "online_pharmacy"
    },
    "order": {
      "orderId": "EXAMPLE-001",
      "placedOn": "2026-10-20",
      "amountPaise": 269677,
      "paidVia": "upi",
      "items": [
        {
          "name": "Dolo",
          "strength": "650",
          "qty": 15
        }
      ],
      "isTestOrder": false
    },
    "events": {
      "refundRequestedOn": "2026-10-22",
      "supportContactedOn": "2026-10-28"
    },
    "today": "2026-10-30"
  },
  "output": {
    "message": {
      "subject": "Order support request — EXAMPLE-001",
      "body": "Hello,\nMy refund is pending.\nOrder ID: EXAMPLE-001\nPlaced on: 2026-10-20\nAmount: ₹2696.77\nPayment method: upi\nItems: Dolo / 650 / qty 15\nRefund requested on: 2026-10-22\nSupport contacted on: 2026-10-28\nPlease confirm the refund status and reference.\nPlease confirm the amount due for refund.\nPlease refund to my original payment method.\nThank you.",
      "lang": "en"
    },
    "evidence": [
      "Order confirmation and bill",
      "Payment record, if paid",
      "Support conversation, if available"
    ],
    "ladder": [
      {
        "level": 1,
        "who": "Seller support",
        "how": "Use the seller's email or order app chat",
        "contact": {
          "value": "care@1mg.com",
          "sourceUrl": "https://www.1mg.com/aboutUs",
          "dateSeen": "2026-10-23"
        },
        "when": "now",
        "why": "Ask the seller first"
      },
      {
        "level": 2,
        "who": "Grievance officer",
        "how": "Email",
        "contact": {
          "value": "grievance-officer@1mg.com",
          "sourceUrl": "https://www.1mg.com/grievance-redressal-policy",
          "dateSeen": "2026-10-23"
        },
        "when": "2026-10-30",
        "why": "Secondary sources describe acknowledgement within 48 hours and redress within 1 month; check on the official site"
      },
      {
        "level": 3,
        "who": "National Consumer Helpline (NCH)",
        "how": "1915 / WhatsApp 8800001915 / https://consumerhelpline.gov.in",
        "contact": {
          "value": "1915",
          "sourceUrl": "https://newsonair.gov.in/toll-free-number-in-17-languages-for-consumers-grievance-redressal-across-the-country-govt-in-ls/",
          "dateSeen": "2026-10-24"
        },
        "when": "2026-11-01",
        "why": "If there is no reply by the acknowledgement check, ask the helpline about next options; check on the official site"
      }
    ],
    "followUps": [
      {
        "dueOn": "2026-11-01",
        "text": "Check acknowledgement; check on the official site",
        "basis": "planned",
        "complaintDate": "2026-10-30"
      },
      {
        "dueOn": "2026-11-29",
        "text": "Check resolution status; check on the official site",
        "basis": "planned",
        "complaintDate": "2026-10-30"
      }
    ],
    "notes": [
      "Message is a draft for you to review and send.",
      "SECONDARY SOURCES ONLY (news and law-firm notes). Every item must be checked on the official page and re-dated before the app shows it to a patient. Until then the app must label it 'check on the official site'.",
      "check on the official site",
      "Refund completion time is not verified; no number is promised.",
      "ASSUMPTION: wait 2 days after contacting support before escalation; this is not a verified rule.",
      "ASSUMPTION: resolution reminder uses +30 days as specified; it is not a calendar-month calculation or a verified deadline.",
      "Follow-ups are planned dates. Recompute with events.grievanceSentOn after you actually send the complaint."
    ],
    "disclaimer": "Review and send this message yourself. Parchi does not send messages, handle money or provide legal advice.",
    "precautions": []
  }
}
```

## report_hi
```json
{
  "input": {
    "lang": "hi",
    "issue": "lab_report_late",
    "seller": {
      "name": "Metropolis",
      "kind": "lab"
    },
    "order": {
      "orderId": "EXAMPLE-001",
      "placedOn": "2026-10-20",
      "amountPaise": 269677,
      "paidVia": "upi",
      "items": [
        {
          "name": "Dolo",
          "strength": "650",
          "qty": 15
        }
      ],
      "isTestOrder": false
    },
    "events": {
      "refundRequestedOn": "2026-10-22",
      "supportContactedOn": "2026-10-28"
    },
    "today": "2026-10-30"
  },
  "output": {
    "message": {
      "subject": "ऑर्डर संबंधी अनुरोध — EXAMPLE-001",
      "body": "नमस्ते,\nमेरी लैब रिपोर्ट में देरी हो रही है।\nऑर्डर आईडी: EXAMPLE-001\nऑर्डर की तारीख: 2026-10-20\nरकम: ₹2696.77\nभुगतान का तरीका: upi\nसामान: Dolo / 650 / संख्या 15\nरिफंड मांगा: 2026-10-22\nसपोर्ट से संपर्क किया: 2026-10-28\nकृपया बताएं कि मेरी रिपोर्ट कब मिलेगी।\nधन्यवाद।",
      "lang": "hi"
    },
    "evidence": [
      "ऑर्डर की पुष्टि और बिल",
      "भुगतान का रिकॉर्ड, यदि भुगतान किया है",
      "सपोर्ट से हुई बातचीत, यदि मौजूद है"
    ],
    "ladder": [
      {
        "level": 1,
        "who": "विक्रेता सपोर्ट",
        "how": "ईमेल या ऑर्डर के ऐप चैट से संपर्क करें",
        "contact": {
          "value": "support@metropolisindia.com",
          "sourceUrl": "https://www.metropolisindia.com/complaints-and-grievance-redressal-policy",
          "dateSeen": "2026-10-23"
        },
        "when": "now",
        "why": "पहले विक्रेता से संपर्क करें"
      },
      {
        "level": 2,
        "who": "शिकायत अधिकारी",
        "how": "ईमेल",
        "contact": {
          "value": "nodal.officer@metropolisindia.com",
          "sourceUrl": "https://www.metropolisindia.com/complaints-and-grievance-redressal-policy",
          "dateSeen": "2026-10-23"
        },
        "when": "2026-10-30",
        "why": "दिए गए द्वितीयक स्रोतों में 48 घंटे में पावती और 1 महीने में निवारण बताया गया है; check on the official site"
      },
      {
        "level": 3,
        "who": "National Consumer Helpline (NCH)",
        "how": "1915 / WhatsApp 8800001915 / https://consumerhelpline.gov.in",
        "contact": {
          "value": "1915",
          "sourceUrl": "https://newsonair.gov.in/toll-free-number-in-17-languages-for-consumers-grievance-redressal-across-the-country-govt-in-ls/",
          "dateSeen": "2026-10-24"
        },
        "when": "2026-11-01",
        "why": "जवाब न मिले तो हेल्पलाइन से अगले विकल्प पूछें; check on the official site"
      }
    ],
    "followUps": [
      {
        "dueOn": "2026-11-01",
        "text": "पावती जांचें; check on the official site",
        "basis": "planned",
        "complaintDate": "2026-10-30"
      },
      {
        "dueOn": "2026-11-29",
        "text": "निवारण की स्थिति जांचें; check on the official site",
        "basis": "planned",
        "complaintDate": "2026-10-30"
      }
    ],
    "notes": [
      "Hindi wording is draft; native review pending.",
      "SECONDARY SOURCES ONLY (news and law-firm notes). Every item must be checked on the official page and re-dated before the app shows it to a patient. Until then the app must label it 'check on the official site'.",
      "check on the official site",
      "Refund completion time is not verified; no number is promised.",
      "ASSUMPTION: wait 2 days after contacting support before escalation; this is not a verified rule.",
      "ASSUMPTION: resolution reminder uses +30 days as specified; it is not a calendar-month calculation or a verified deadline.",
      "Follow-ups are planned dates. Recompute with events.grievanceSentOn after you actually send the complaint."
    ],
    "disclaimer": "यह संदेश आप जांचकर खुद भेजें। पर्ची संदेश नहीं भेजती, पैसे नहीं संभालती और कानूनी सलाह नहीं देती।",
    "precautions": []
  }
}
```

## sandbox
```json
{
  "input": {
    "lang": "en",
    "issue": "cancelled_by_seller",
    "seller": {
      "name": "Tata 1mg",
      "kind": "online_pharmacy"
    },
    "order": {
      "orderId": "EXAMPLE-001",
      "placedOn": "2026-10-20",
      "amountPaise": 269677,
      "paidVia": "upi",
      "items": [
        {
          "name": "Dolo",
          "strength": "650",
          "qty": 15
        }
      ],
      "isTestOrder": true
    },
    "events": {
      "refundRequestedOn": "2026-10-22",
      "supportContactedOn": "2026-10-28"
    },
    "today": "2026-10-30"
  },
  "output": {
    "message": {
      "subject": "Test order — Order support request — EXAMPLE-001",
      "body": "Hello,\nThe seller cancelled my order.\nOrder ID: EXAMPLE-001\nPlaced on: 2026-10-20\nAmount: ₹2696.77\nPayment method: upi\nItems: Dolo / 650 / qty 15\nRefund requested on: 2026-10-22\nSupport contacted on: 2026-10-28\nPlease explain the cancellation and confirm the refund status.\nPlease refund to my original payment method.\nThank you.",
      "lang": "en"
    },
    "evidence": [
      "Order confirmation and bill",
      "Payment record, if paid",
      "Support conversation, if available"
    ],
    "ladder": [],
    "followUps": [],
    "notes": [
      "Message is a draft for you to review and send.",
      "Sandbox only: no real seller contact or escalation."
    ],
    "disclaimer": "Review and send this message yourself. Parchi does not send messages, handle money or provide legal advice.",
    "precautions": []
  }
}
```

## unknown_contact
```json
{
  "input": {
    "lang": "en",
    "issue": "late",
    "seller": {
      "name": "Example unknown seller",
      "kind": "online_pharmacy"
    },
    "order": {
      "orderId": "EXAMPLE-001",
      "placedOn": "2026-10-20",
      "amountPaise": 269677,
      "paidVia": "upi",
      "items": [
        {
          "name": "Dolo",
          "strength": "650",
          "qty": 15
        }
      ],
      "isTestOrder": false
    },
    "events": {
      "refundRequestedOn": "2026-10-22",
      "supportContactedOn": "2026-10-28"
    },
    "today": "2026-10-30"
  },
  "output": {
    "message": {
      "subject": "Order support request — EXAMPLE-001",
      "body": "Hello,\nMy order is late.\nOrder ID: EXAMPLE-001\nPlaced on: 2026-10-20\nAmount: ₹2696.77\nPayment method: upi\nItems: Dolo / 650 / qty 15\nRefund requested on: 2026-10-22\nSupport contacted on: 2026-10-28\nPlease confirm a revised delivery date.\nThank you.",
      "lang": "en"
    },
    "evidence": [
      "Order confirmation and bill",
      "Payment record, if paid",
      "Support conversation, if available"
    ],
    "ladder": [
      {
        "level": 1,
        "who": "Seller support",
        "how": "Use the seller's email or order app chat",
        "contact": null,
        "when": "now",
        "why": "Ask the seller first"
      },
      {
        "level": 3,
        "who": "National Consumer Helpline (NCH)",
        "how": "1915 / WhatsApp 8800001915 / https://consumerhelpline.gov.in",
        "contact": {
          "value": "1915",
          "sourceUrl": "https://newsonair.gov.in/toll-free-number-in-17-languages-for-consumers-grievance-redressal-across-the-country-govt-in-ls/",
          "dateSeen": "2026-10-24"
        },
        "when": "now",
        "why": "You can ask the helpline about next options; check on the official site"
      }
    ],
    "followUps": [],
    "notes": [
      "Message is a draft for you to review and send.",
      "SECONDARY SOURCES ONLY (news and law-firm notes). Every item must be checked on the official page and re-dated before the app shows it to a patient. Until then the app must label it 'check on the official site'.",
      "check on the official site",
      "Refund completion time is not verified; no number is promised.",
      "we could not find a contact for this company",
      "ASSUMPTION: wait 2 days after contacting support before escalation; this is not a verified rule.",
      "No grievance contact found; use the helpline option."
    ],
    "disclaimer": "Review and send this message yourself. Parchi does not send messages, handle money or provide legal advice.",
    "precautions": []
  }
}
```

## wrong_hi
```json
{
  "input": {
    "lang": "hi",
    "issue": "wrong_item",
    "seller": {
      "name": "Blinkit",
      "kind": "quick_commerce"
    },
    "order": {
      "orderId": "EXAMPLE-001",
      "placedOn": "2026-10-20",
      "amountPaise": 269677,
      "paidVia": "upi",
      "items": [
        {
          "name": "Dolo",
          "strength": "650",
          "qty": 15
        }
      ],
      "isTestOrder": false
    },
    "events": {
      "refundRequestedOn": "2026-10-22",
      "supportContactedOn": "2026-10-28"
    },
    "today": "2026-10-30"
  },
  "output": {
    "message": {
      "subject": "ऑर्डर संबंधी अनुरोध — EXAMPLE-001",
      "body": "नमस्ते,\nमिला हुआ सामान मेरे ऑर्डर से मेल नहीं खाता।\nऑर्डर आईडी: EXAMPLE-001\nऑर्डर की तारीख: 2026-10-20\nरकम: ₹2696.77\nभुगतान का तरीका: upi\nसामान: Dolo / 650 / संख्या 15\nरिफंड मांगा: 2026-10-22\nसपोर्ट से संपर्क किया: 2026-10-28\nकृपया सही सामान भेजें या रिफंड करें।\nधन्यवाद।",
      "lang": "hi"
    },
    "evidence": [
      "ऑर्डर की पुष्टि और बिल",
      "भुगतान का रिकॉर्ड, यदि भुगतान किया है",
      "सपोर्ट से हुई बातचीत, यदि मौजूद है",
      "मिले हुए सामान का रिकॉर्ड"
    ],
    "ladder": [
      {
        "level": 1,
        "who": "विक्रेता सपोर्ट",
        "how": "ईमेल या ऑर्डर के ऐप चैट से संपर्क करें",
        "contact": {
          "value": "info@blinkit.com",
          "sourceUrl": "https://blinkit.com/terms",
          "dateSeen": "2026-10-23"
        },
        "when": "now",
        "why": "पहले विक्रेता से संपर्क करें"
      },
      {
        "level": 2,
        "who": "शिकायत अधिकारी",
        "how": "ईमेल",
        "contact": {
          "value": "grievance.officer@blinkit.com",
          "sourceUrl": "https://blinkit.com/terms",
          "dateSeen": "2026-10-23"
        },
        "when": "2026-10-30",
        "why": "दिए गए द्वितीयक स्रोतों में 48 घंटे में पावती और 1 महीने में निवारण बताया गया है; check on the official site"
      },
      {
        "level": 3,
        "who": "National Consumer Helpline (NCH)",
        "how": "1915 / WhatsApp 8800001915 / https://consumerhelpline.gov.in",
        "contact": {
          "value": "1915",
          "sourceUrl": "https://newsonair.gov.in/toll-free-number-in-17-languages-for-consumers-grievance-redressal-across-the-country-govt-in-ls/",
          "dateSeen": "2026-10-24"
        },
        "when": "2026-11-01",
        "why": "जवाब न मिले तो हेल्पलाइन से अगले विकल्प पूछें; check on the official site"
      }
    ],
    "followUps": [
      {
        "dueOn": "2026-11-01",
        "text": "पावती जांचें; check on the official site",
        "basis": "planned",
        "complaintDate": "2026-10-30"
      },
      {
        "dueOn": "2026-11-29",
        "text": "निवारण की स्थिति जांचें; check on the official site",
        "basis": "planned",
        "complaintDate": "2026-10-30"
      }
    ],
    "notes": [
      "Hindi wording is draft; native review pending.",
      "विक्रेता की पुष्टि मिलने तक इस दवा का इस्तेमाल न करें। (reviewed: false)",
      "SECONDARY SOURCES ONLY (news and law-firm notes). Every item must be checked on the official page and re-dated before the app shows it to a patient. Until then the app must label it 'check on the official site'.",
      "check on the official site",
      "Refund completion time is not verified; no number is promised.",
      "ASSUMPTION: wait 2 days after contacting support before escalation; this is not a verified rule.",
      "ASSUMPTION: resolution reminder uses +30 days as specified; it is not a calendar-month calculation or a verified deadline.",
      "Follow-ups are planned dates. Recompute with events.grievanceSentOn after you actually send the complaint."
    ],
    "disclaimer": "यह संदेश आप जांचकर खुद भेजें। पर्ची संदेश नहीं भेजती, पैसे नहीं संभालती और कानूनी सलाह नहीं देती।",
    "precautions": [
      {
        "text": "विक्रेता की पुष्टि मिलने तक इस दवा का इस्तेमाल न करें।",
        "reviewed": false
      }
    ]
  }
}
```
