# NEXUS

**DSN FUTMinna Student Intelligence & Opportunity Platform**

NEXUS helps students understand *where they are*, *where they want to go*, and
*what to do next* — turning scattered academic/skill/opportunity information into
context, recommendations and action. This repo holds the **v1 pilot foundation**
for the DSN AI Bootcamp.

> Full concept: see `NEXUS.docx`.

## Status
The design-audit changes are implemented. See [changes-made1.md](changes-made1.md) for the change rationale, validation evidence, pilot limits, and a real-user testing script. Visual conventions are in [DESIGN.md](DESIGN.md).

✅ **Golden path runnable** — signup → profile → skill gaps → matched
opportunities → next action all work in the Streamlit app on a zero-setup
SQLite database locally. The cloud entrypoint uses Supabase Auth and PostgreSQL.
See [deployment instructions](docs/deployment.md) for Streamlit Community Cloud,
email setup, release checks and pilot limitations.

## What "v1 working" means (the golden path)
One real student can, unaided, in one sitting:
1. Sign up / log in
2. Build a profile (academic + skills + target career + interests)
3. See a **skill-gap analysis** vs their target career
4. See **matched opportunities** with a % score and *why it matches*
5. Get **one recommended next action** from their biggest gap

Out of scope for v1: university-portal integration, ML-based recommendations,
community analytics, mobile app, full Knowledge Vault.

## Tech stack (pilot)
| Layer | Choice |
|---|---|
| Database + Auth + API | **Supabase** (PostgreSQL) |
| Intelligence | **SQL views + Python** (rule-based, transparent) |
| Frontend | **Streamlit** (see `docs/frontend-decision.md`) |
| Non-coder data entry | Google Forms + Airtable/Sheets |
| Analytics | `events` table (+ optional PostHog) |

## Repo layout
```
streamlit_app.py         # cloud entrypoint (Supabase required)
app/                     # Streamlit UI, cloud adapter and local SQLite support
  app.py                 # golden-path UI: auth → profile → gaps → matches → feedback
  intelligence.py        # rule-based engine (mirrors the SQL views), pure & unit-tested
  db.py                  # local SQLite adapter
  cloud_db.py            # Supabase adapter using per-user JWTs
  seed_db.py             # builds nexus.db from schema_sqlite.sql + data/*.csv
  schema_sqlite.sql      # SQLite mirror of db/schema.sql
  requirements.txt       # streamlit, pandas
  tests/test_intelligence.py  # reproduces the proposal's worked example
db/
  schema.sql     # tables, enums, triggers, and the 3 intelligence views (production)
  seed.sql       # proficiency scale, ~70-skill taxonomy, 5 careers, answer key, demo opps
  policies.sql   # Supabase row-level security (privacy model)
docs/
  frontend-decision.md   # ADR: why Streamlit for the pilot
  career-pathways.md     # human-readable "answer key" (owned by Data/Research)
  student-survey.md      # problem-validation + pilot-recruitment survey
data/
  skill_taxonomy.csv     # taxonomy for Airtable/Sheets (non-coder contribution)
  careers.csv, career_skills.csv          # the 5 careers + their answer key
  opportunities.csv, opportunity_*.csv    # demo opportunities + skill/career links
NEXUS.docx       # the original concept proposal
```

## Run the pilot app (fastest — this is the bootcamp demo)
No database server needed; the app self-creates a local `nexus.db`.
```bash
pip install -r app/requirements.txt
python app/seed_db.py            # build + seed the DB (also creates a demo login)
streamlit run app/app.py         # opens http://localhost:8501
```
Log in with **demo@nexus.test / demo1234** to see a pre-filled Data-Scientist
student, or create a fresh account and build a profile from scratch.

Verify the intelligence is correct (zero dependencies):
```bash
python app/tests/test_intelligence.py
```

Additional regression checks:
```bash
python app/tests/test_tagger.py
python app/tests/test_pilot_ui.py
```
The UI checks require the app dependencies and use an isolated temporary database. The pilot UI uses Streamlit 1.63 or later. Run from the project root to load the green, white, and red theme.

Opportunity ingestion lives in `app/ingest.py`, with adapters in `app/sources.py` and skill extraction in `app/tagger.py`. Run `python app/ingest.py` to fetch sources or `python app/ingest.py --offline` for demonstration data. Sample listings are isolated from live listings and have no application links.

Optional environment variables: `NEXUS_SUPPORT_URL` adds a real pilot support link; `NEXUS_SHOW_DEMO=1` shows the demo-login hint; `NEXUS_DB_PATH` chooses a separate database for testing.

## Set up the production database (Supabase)
```bash
psql "$DATABASE_URL" -f db/schema.sql
psql "$DATABASE_URL" -f db/seed.sql
psql "$DATABASE_URL" -f db/policies.sql   # Supabase only (uses auth.uid())
```
Quick check the intelligence works — after a student profile + skills exist:
```sql
select skill_name, current_rank, target_rank, gap_label
from v_skill_gaps where student_id = '<uuid>' order by priority desc;

select title, match_score, skill_match_pct, matched_skills
from v_opportunity_matches where student_id = '<uuid>' order by match_score desc;
```

## The 5 v1 career pathways
Data Scientist · AI Engineer · Software Developer · Product Designer · Digital Marketer
→ target skills + levels in `docs/career-pathways.md`.

## How this maps to the teams
- **Data & Analytics / Research** → own `career-pathways.md`, run the survey, seed opportunities.
- **ML & Intelligence** → tune the match/gap logic in `db/schema.sql` views.
- **Backend & Data Engineering** → Supabase setup, auth, APIs.
- **Frontend / Product** → the Streamlit golden path.
- **Documentation & Knowledge** → keep this README + docs current.

## Data responsibility
Privacy is a foundational requirement, not an afterthought. Consent is captured
on the profile; row-level security (`policies.sql`) ensures a student sees only
their own data; academic data is never exposed publicly.
