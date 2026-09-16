# Changes made 1 — NEXUS pilot usability

Date: 15 September 2026

## Outcome

Implemented the design audit's usability and trust fixes while keeping the Streamlit + SQLite pilot. The UI now follows a green, white, and red system. This version is ready for a facilitated usability session; adoption must be demonstrated by real users, not assumed from passing tests.

Your existing database and profile were not reset. Automated writes used a temporary test database. No deployment or Git commit was made (this folder has no Git metadata).

## What changed and why

| Area | What changed | Why |
|---|---|---|
| Brand and colors | White background, green actions/text/surfaces, red brand accent, focus and warning/error treatments. Added `.streamlit/config.toml`, `app/styles.css`, and `DESIGN.md`. Built-in information/success colors use the same green palette. | Gives NEXUS a consistent identity and removes unrelated blue/orange accents. |
| Entry screen | Clear student outcome, constrained 520px authentication area, stronger primary buttons, 16px form text and larger controls. | Students can understand the benefit and use forms on smaller screens. |
| Account help | Added a visible “Need help signing in?” section with an honest DSN facilitator support route. Optional `NEXUS_SUPPORT_URL` adds a real support button when configured. | Provides a recovery path without pretending a password-reset service exists. |
| Signup | Shows the six-character password requirement; validates trimmed name, email format, and password both in UI and database account creation. | Users see requirements before submitting; invalid inputs are rejected consistently. |
| Demo credentials | Public demo-login hint is hidden unless `NEXUS_SHOW_DEMO=1`. Existing demo account remains available for controlled testing. | Keeps demonstration details out of the normal student experience. |
| Navigation | Replaced the overlay sidebar with a visible, labeled Navigate selector on every signed-in page. Added direct next-step buttons. | Small-screen users no longer have to open and dismiss a drawer to move between tasks. |
| Save confirmations | Academic, skills, interests, saved opportunities, and refresh feedback survive reruns through a session notice. Logout clears all per-user UI state. | Confirms the action actually happened and avoids carrying one account's UI state into another. |
| Profile assessment | Career-relevant skills appear first, followed by remaining categories without duplicates. Groups show saved rated counts. Added behavioral definitions for all five proficiency levels. | Reduces searching and makes self-ratings more consistent. “Rated” counts mean Beginner or above, not verified proficiency. |
| Skill gaps | Replaced the wide table with wrapping skill rows showing current level, target, and priority. Condensed summary metrics and made the highest-priority step prominent. | The key comparison remains readable without sideways scrolling. |
| Completed/empty states | All-on-track state explains self-rating limits and offers Explore opportunities; missing target offers Choose my target career. | A successful or incomplete profile no longer ends at an unexplained dash. |
| Recommendation language | Removed the unqualified overall match badge. Shows weighted tagged-skills coverage, matched/total tags, missing ratings, inferred career tag, title-based experience hints, recorded academic limits, and requirements to verify. | Skill overlap is not a probability of acceptance or complete eligibility assessment. The existing mathematical engine remains unchanged; the UI no longer overstates its output. |
| Tagging defect | Confirmed that CNN in the customer-support posting's client list was interpreted as deep learning. Removed the ambiguous bare CNN alias and retained explicit convolutional-neural-network wording. | Corrects a concrete false positive. Acronym-only CNN requirements are conservatively no longer detected without another matching term. |
| Existing live-feed tags | Recomputes live-feed skill and career tags in memory using current rules before displaying matches. Curated tags and stored user data remain intact. | Corrected rules affect already-fetched listings immediately, without reseeding or waiting for refresh. A read-back confirmed the support listing no longer includes Deep Learning or the AI Engineer career tag. |
| Live versus sample | Separate Live listings and Sample listings views; live is the default. Source=sample and example.org/com/net destinations are recognized as demonstrations. Samples have no application link. | Students can distinguish practice content from actionable listings. Sample items may still be saved in their separate view. |
| Opportunity browsing | Added title/organization search, type/source/experience/career-tag filters, saved-only view, coverage/deadline sorting, ten-result batches, and empty-result guidance. | Makes a long list manageable and saved items retrievable. Changing filters resets the visible batch. |
| Opportunity details | Replaced repeated cards and duplicate percentages with separated results and expandable requirement details. Expired dated entries are excluded. Application URLs must use HTTP(S) and have a valid hostname. | Reduces noise and avoids unusable or inappropriate application links. URL checks do not verify the trustworthiness or current availability of a listing. |
| Freshness | Counts live and sample content separately, shows the fetch time and source-verification reminder. UI refresh calls live adapters only and reports zero-fetch failure without pretending samples are new live results. | Makes feed state more honest. Partial source failures remain possible and are logged by the ingestion layer. |
| Feedback | All three ratings start unselected, have labeled scales, and are required deliberately. Neutral copy asks what helped or got in the way. A success state prevents accidental resubmission within the same session. | Avoids defaults that manufacture apparent improvement and reduces duplicate feedback. |
| Developer chrome | Configured Streamlit viewer toolbar mode, removing Deploy from the tested login view. | Makes the student interface less like an internal development tool. Streamlit's standard menu remains; development file-change prompts can appear while code is being edited. |

## Validation performed

**24 tests passed:**

- `python app/tests/test_intelligence.py` — 7 existing recommendation tests.
- `python app/tests/test_tagger.py` — 10 existing tagging tests.
- `python app/tests/test_pilot_ui.py` — 7 new regression tests, including multi-step Streamlit AppTest flows.
- Python compilation passed for the updated application and presentation helpers.
- Read-only verification against existing opportunity data confirmed the CNN correction reaches the displayed matching data.
- Real-browser inspection confirmed the new light green/white login UI and removal of Deploy. The browser session available after restarting the server remained on login, so final authenticated visual verification was not completed. Signed-in flow checks above used AppTest, not screenshots.
- Exact mobile viewport certification is still pending. The earlier browser viewport override did not report the requested dimensions reliably. The new layout removes the known horizontal-table and overlay-navigation problems structurally.

New tests use `NEXUS_DB_PATH` pointing to a disposable temporary database. They do not add test accounts or feedback to `nexus.db`.

## How to run

From the NEXUS project directory:

```powershell
python -m pip install -r app/requirements.txt
python -m streamlit run app/app.py
```

Open `http://localhost:8501`. The verified runtime is Streamlit 1.63; requirements now specify `streamlit>=1.63,<2`. Start from the project root so the theme configuration is loaded. Restart the server if configuration changes do not appear.

Optional pilot setup:

- Set `NEXUS_SUPPORT_URL` to the real DSN pilot support page before inviting users if a clickable support route is available.
- Set `NEXUS_SHOW_DEMO=1` only when you want the demo login hint shown.
- Use a separate `NEXUS_DB_PATH` for disposable tests. Omitting it uses the existing `nexus.db`.
- Refresh live listings before the session and verify several application destinations manually. A fresh offline database contains samples only; its live view will be empty until ingestion succeeds.

## Put this in front of real users

Run a first session with five students and a facilitator who can provide account help. Ask students to complete these tasks without coaching:

1. Explain what NEXUS helps them do from the entry screen.
2. Create an account, choose a career, and rate relevant skills using the level definitions.
3. Find their highest-priority skill gap and describe a specific next action.
4. Find one suitable live opportunity, explain what the coverage number does and does not mean, and check the original requirements.
5. Save it, navigate away, and retrieve it using Saved only.
6. Submit candid feedback, including what would make them return next week.

Record completion, confusion, incorrect assumptions, and whether they can name a useful action. Follow up after one week to see whether they return and act. Do not interpret a high coverage percentage or positive survey rating alone as adoption.

## Pilot limits retained deliberately

- Facilitator-assisted account help only; no email reset, email verification, or automated recovery service was added.
- Self-rated skill coverage ignores proficiency depth. Tags and career links are heuristic; experience labels are inferred from title/type. Country eligibility, years of experience, and application validity need checking at the source.
- Removing bare CNN fixes the observed false positive; it does not make the entire text tagger semantically reliable.
- No new hosted deployment, production authentication migration, access-control/security audit, or load test was performed.
- Refresh may partially succeed. Existing cached postings can be stale when their source provides no deadline.
- Feedback duplicate prevention is session-scoped, not a database-wide one-response policy.
- Initial academic defaults and the existing profile-completeness formula remain as before; review them with students during onboarding tests.

## Files changed

- `.streamlit/config.toml`
- `app/app.py`
- `app/db.py`
- `app/presentation.py`
- `app/styles.css`
- `app/tagger.py`
- `app/requirements.txt`
- `app/tests/test_pilot_ui.py`
- `DESIGN.md`
- `README.md`
- `changes-made1.md`

The original audit remains unchanged as the before-state record.

## Supabase and cloud release changes — 16 September 2026

### What changed and why

- Added `app/cloud_db.py`: Supabase Auth and PostgreSQL persistence, with one
  client per Streamlit session. Tester data survives Streamlit restarts and
  sessions cannot share authentication tokens.
- Added `streamlit_app.py` as the cloud entrypoint. It requires Supabase so a
  missing configuration cannot silently create a temporary SQLite database.
- Applied three tracked migrations for the schema, current reference data,
  row-level security, safe SQL views, atomic skill/interest updates, indexes,
  profile identity checks and analytics consent enforcement.
- Bound profile email to the signed-in email and excluded role changes from
  student permissions. This prevents another account reserving a tester's email
  or granting itself administrative access.
- Made consent functional: withdrawing it pauses personalized results and new
  usage analytics. Profile editing and voluntary feedback remain available.
  Added clear text explaining storage, withdrawal and deletion requests.
- Loaded 27 live tagged postings from public feeds. Five examples remain marked
  as samples with applications disabled. Shared content is refreshed by the
  pilot operator, not by student sessions.
- Added deterministic paginated reads, concurrent-login recovery, neutral cloud
  errors, ignored local secrets, deploy templates and a pinned dependency lock.
- Added `docs/deployment.md` with setup, validation, refresh and rollback steps.
  The green, white and red design remains in place.

### Validation and limits

All 25 local checks pass: 17 matching/tagging checks and eight UI checks, including consent withdrawal.
Transactional database checks verify isolation between two users, role protection,
atomic writes, anonymous denial, email identity and analytics consent. A disposable
account passed the actual Supabase API flow through login, profile, skills,
interests, matching, save/unsave, feedback and logout; it was removed afterward.
The Supabase security advisor reported no findings after fixes.

This is still a facilitated prototype. Real-email signup and the deployed URL
must be verified before invitations; custom SMTP is required for external email
confirmation. Password recovery/deletion remain facilitator-assisted. Feed refresh
is manual. The app's rules and inferred tags do not guarantee eligibility, hiring
outcomes, availability or adoption. Use the existing pilot script to measure
whether testers find a useful next action and return to use NEXUS.
