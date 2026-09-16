# NEXUS pilot deployment

## Release target

- Repository: https://github.com/dsnfutminna-netizen/NEXUS
- Host: Streamlit Community Cloud
- Branch: `main`
- Main file: `streamlit_app.py`
- Python: 3.11 (the release validation environment)
- Supabase project: `lwijsbtscqawpbxlnubz` (eu-west-1)
- Early testing: 16–20 September 2026

## What is ready

Supabase schema, Auth integration, reference data, student RLS policies and three
migrations are applied. There are 72 skills, five careers, 77 required-skill rules,
223 aliases, 27 live tagged listings and five clearly labelled sample listings.
No local student profiles or passwords were migrated. Local SQLite data remains
on the original machine. Testers create new Supabase accounts.

## Deploy on Streamlit Community Cloud

1. Sign in at https://share.streamlit.io using the account with repository access.
2. Create an app from `dsnfutminna-netizen/NEXUS`, branch `main`, main file
   `streamlit_app.py`. Choose Python 3.11 in advanced settings if available.
3. Copy the values from the local, ignored `.streamlit/secrets.toml` into the
   app's Secrets settings. They contain the project URL and publishable key only.
   `.streamlit/secrets.example.toml` documents the supported fields.
4. Deploy and record the assigned `https://...streamlit.app` address.
5. Set `NEXUS_APP_URL` to that address in Streamlit Secrets. In Supabase Auth URL
   Configuration, set Site URL and the allowed redirect URL to the same address.
6. Set `NEXUS_SUPPORT_URL` to the pilot team's chosen help link, if available.
7. Complete the real-email registration and confirmation check below before
   distributing the link.

The cloud entrypoint always uses Supabase and stops when credentials are missing.
Never put a service-role/secret key in Streamlit Secrets. The student app uses
only a publishable key and a separate authenticated client for each session.

## Email delivery is a launch requirement

Email confirmation is enabled. Verify custom SMTP is configured in Supabase
Authentication settings and send a confirmation to an actual external tester.
Supabase's default SMTP only sends to project-team addresses and has a very low
rate limit; an API login test cannot prove confirmation-email delivery.
See https://supabase.com/docs/guides/auth/auth-smtp . Keep credentials in the
Supabase dashboard, never in the repository or chat.

The current app confirms email through Supabase's link and then asks the user
to log in. Refreshing the browser can require signing in again. Password recovery
and deletion requests are handled by the pilot facilitator for this prototype;
there is no self-service password reset or account deletion screen yet.

## Release validation

Local checks (run with the locked environment):

```powershell
python -m pip install -r requirements.txt
python app/tests/test_intelligence.py
python app/tests/test_tagger.py
python app/tests/test_pilot_ui.py
```

Remote checks completed on 16 September:

- Transactional two-user RLS checks (`db/test_rls.sql`), including cross-user
  access denial, role escalation denial, atomic skill updates, anonymous denial.
- Profile email must equal the authenticated email; analytics inserts require
  consent. Separate transactional regression checks passed.
- Real Supabase API login, profile creation/update, taxonomy, skill and interest
  persistence, opportunity matching, save/unsave, feedback, events and logout.
  The disposable fixture and its records were removed afterward.
- Security advisors: no findings after restricting the pre-existing internal
  `rls_auto_enable` function. Missing foreign-key indexes were added. Unused-index
  notices are expected on a newly initialized pilot database.

Before inviting testers: open the deployed app in two separate browser sessions,
register with a real external email, confirm, save a profile, consent, rate skills,
view gaps, save a live listing, submit feedback, log out and back in. Confirm the
second account cannot see the first account's profile or saves. Also withdraw
consent and verify personalized results pause.

## Refresh opportunity feeds

```powershell
python scripts/refresh_cloud_opportunities.py
```

Review `release-private/opportunities.sql` and execute it using the Supabase SQL
Editor as the operator. This script fetches public feeds and never reads local
student data. It updates matching feed listings and their inferred tags in one
transaction. It does not automatically deactivate postings missing from a feed;
operators must check availability and deactivate withdrawn listings. Listings
remain unverified external opportunities; users must check source requirements.

The student app cannot edit shared feeds. No scheduled refresh job is configured.
For this short pilot, refresh before each testing session.

## Schema and dependencies

`supabase/migrations/` is the applied, ordered schema history. Filenames match the
remote migration versions returned by Supabase after application. The first
migration includes the reference seed; later migrations record review fixes.
Do not rerun the initial schema against an existing database. `db/schema.sql` and
`db/policies.sql` are readable definitions; the older `db/seed.sql` is historical.
Regenerate current reference data with `python scripts/build_cloud_seed.py`.

`requirements.lock` pins the cross-platform dependency set. Update it with
`uv pip compile app/requirements.txt --universal --output-file requirements.lock`.
The root `requirements.txt` uses that lock for Streamlit Cloud.

## Rollback and data handling

Revert a code commit and redeploy to roll back the app. Preserve Supabase data;
do not drop/reset the project as a code rollback. For schema changes, create a
forward migration. Export pilot feedback through an authorized operator account
and agree a retention/deletion date with participants. Local databases, secrets,
agent state and disposable test credentials are excluded by `.gitignore`.
