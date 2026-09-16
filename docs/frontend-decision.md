# ADR 0001 — Frontend for the pilot: Streamlit

**Status:** Accepted (for the pilot / DSN AI Bootcamp demo)
**Date:** 2026-09-12
**Decision owner:** NEXUS core team

## Context
We need a *testable* version of NEXUS to present at the upcoming DSN AI Bootcamp.
The differentiator of NEXUS is the **intelligence layer** (skill-gap analysis,
opportunity matching), not the UI. Our community is data/Python-heavy, we are on
a short timeline, and we want the whole cohort — not just frontend specialists —
to be able to contribute.

## Decision
Build the **pilot UI in Streamlit** (Python), on top of the Supabase/Postgres
backend defined in `/db`. Keep all business logic (gap analysis, matching) in
plain SQL views + Python functions so it is reusable by any future frontend.

## Rationale
- **Fastest path to a visible intelligence demo.** A Python team can ship the
  full golden path in days, not weeks.
- **Plays to the community's strength** (Python), so more people can build.
- **The intelligence lives in the DB/Python, not the UI** — so switching
  frontends later costs us the UI only, not the brains.
- **Free, trivial hosting** via Streamlit Community Cloud.

## Consequences
- The pilot will look more "app-like dashboard" than "polished product." That is
  an acceptable trade for the bootcamp.
- Auth is lighter in Streamlit; we lean on Supabase Auth and keep sign-in simple.

## Revisit trigger
After the pilot is validated (see `/docs` success metrics), rebuild the
**production** frontend in **Next.js + React** against the *same* Supabase
backend. This ADR should be revisited at that point.

## Alternatives considered
- **Next.js/React now** — best product feel, but slower to first demo and needs
  dedicated frontend people we can't guarantee for the bootcamp deadline.
- **Firebase + web app** — viable, but Supabase's Postgres fits our relational,
  SQL-driven intelligence model far better.
