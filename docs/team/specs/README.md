# Teammate feature specs (24 Oct 2026): three independent pieces, nobody waits for anybody
Written by Claude for Aditya Singh (lead). Read this file first, then your own spec. Each spec is a self-contained module with its own folder, contract, tests and acceptance list. None of them changes `app/`, `server/` or `engine/`; the lead plugs your finished module in later.

| Spec | Owner | What it is | Needs a Mac/iMac? |
|---|---|---|---|
| `SPEC-1-FAMILY-MESSAGES.md` | Aditya Singhal | "Tell my family": short Hindi/English messages for plan ready, order placed, Plan B, lab tomorrow, refill due; one-tap WhatsApp/SMS links; provider slot for real SMS later | No (Python); end-to-end check on the iMac |
| `SPEC-2-RECOMMENDATION-ENGINE.md` | Aditya Singhal | The V3 personal recommendation engine: ranks whole-parchi plans for this person, explains why, learns from the person's own choices | No (Python); end-to-end check on the iMac |
| `SPEC-3-SHOP-REPLY-PAGE.md` | Antara Gupta | Hindi-first reply page for local shops (cheap phones) + "type your reply in one sentence" parser | No (HTML/CSS/JS) |

## Working agreement (applies to all three)
1. Read these files with `git fetch origin && git checkout team/specs` (read only). Do your work on your OWN branch off `origin/main`: `team/<yourname>/<feature>`. Commit ONLY inside your feature folder `teammates/<feature>/` (folder names are in each spec). Open a pull request to `main`; the lead merges. Never push to `main`.
2. Do not edit `app/`, `server/`, `engine/` or any doc outside your folder. If you think the contract needs a change, write it in your `NEEDS-LEAD.md` and keep working with your assumption.
3. No secrets, no keys, no real patient data, no real prescriptions or photos, no scraped data without a source URL and date. Test data is synthetic.
4. Every number you show must come from a result file you commit (`RESULTS.md` + raw output) or be labelled "assumption". No invented claims: "works" means a test you can run.
5. Hard product rules (from CLAUDE.md): Parchi never sells or holds money; never swaps a brand; never recommends doses or tests; H1/X medicines = "buy in person with the original parchi"; sandbox orders say "Test order"; unknown price/stock stays unknown (never zero); no seller pays to change a ranking.
6. Python 3.11, a virtualenv inside your folder, `pytest`. No network at run time except what your spec names.
7. Definition of done: the acceptance list in your spec passes, `README.md` shows how to run it in three commands, `RESULTS.md` has the measured results, and a short "Honest limits" section says what is not proven.

## iMac rules (Aditya Singhal has access; these protect the live demo)
- Work only in `~/teammates/<feature>/` on the iMac. NEVER write to `~/parchi` (server, `data/`, spend ledger, keys, databases). NEVER `rsync --delete` into `~/parchi`. Never stop or restart the demo server, Temporal or the reader.
- Use ports 8040-8049 on `127.0.0.1` for your own services. The demo server on `:8000` is READ-ONLY for you, limited to 120 requests a minute per key: use a test install key that Aditya hands you in person, keep it in the environment variable `PARCHI_TEST_KEY`, never in git, chat or a file in the repo.
- No Anthropic/Claude API calls (the key and the spend cap are the lead's). The Mac has no GPU job queue: keep jobs small.
