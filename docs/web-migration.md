# NEXUS website migration

## Architecture

- **Website:** Next.js 16, React, TypeScript, responsive green/white/red UI, hosted on Vercel with root directory `web`.
- **Accounts and data:** Supabase Auth and PostgreSQL. Server requests use the signed-in user's session and database row-level security. No service key belongs in the website.
- **Recommendations:** transparent rule-based scoring ported from the existing Python engine, checked against deterministic fixtures. Scores indicate profile overlap, not hiring probability.
- **Feedback:** student-owned reports, optional contact permission and usefulness rating; database-authorized administrators can change status, add private notes and export reports.
- **Feeds:** Python worker called manually or by the optional GitHub Actions schedule. A separate protected environment holds its service credential. The schedule stays disabled until explicitly configured.

## Environments

The new test project provided by the owner is `nkllkzpmldmhoxbolgjw`.
The existing Streamlit pilot uses `lwijsbtscqawpbxlnubz`.
Use the test project for acceptance testing before any production cutover. Do not copy student profiles merely to populate the test environment.

## Supabase setup

For an empty project, apply every file in `supabase/migrations` in timestamp order. The existing pilot has schema drift: `feedback_requests`, `feedback_notes`, and `sync_feed_opportunities` exist, but their September migration versions are absent from its history. The October additions and curated programs were applied separately. **Do not run a blanket `supabase db push` against the pilot** until an operator reconciles those two historical versions with the actual objects. Seed reference data using the repository's existing import tooling.

New migrations add feedback tables and policies, an admin role check, private review notes, and an operator-only feed upsert function. They do not delete or replace existing student data. Assign an administrator through a trusted database operator after verifying the user's identity; signup metadata must never grant roles.

The designated support/admin address is `dsnfutminna@datascientistsfoundation.org`. Its owner recovered access and completed onboarding on 20 October 2026. After verifying the Auth identity and profile, an operator assigned that exact profile the `admin` role. The previous pilot admin remains in place. Do not create a role from signup metadata or replace an existing admin without confirming team access.

Supabase dashboard-issued password recovery emails use the project Site URL and may return with an implicit-flow fragment. The landing page hands that recovery session to `/reset-password`; it clears tokens from the browser address before navigating. Keep the Site URL at the production origin and include `/auth/callback` in the allowed redirects for the website-initiated PKCE flow when SMTP is enabled.

Run existing `db/test_rls.sql` and `db/test_identity_consent.sql` in the test project. Complete hosted feedback isolation checks with two student accounts and one operator-designated admin. Local PGlite checks complement this step.

## Vercel setup

Import the NEXUS GitHub repository, select the reviewed migration branch, set root directory **web**, and use the Next.js preset with Node.js 24. Set:

| Variable | Value |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Test project URL for preview; approved pilot project for production |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Matching project's publishable key |
| `NEXT_PUBLIC_SITE_URL` | Exact stable HTTPS origin of this deployment |

Never enter a service-role key into a `NEXT_PUBLIC_` variable. Environment changes require a fresh build. Keep production and preview variables separate, and use a stable test hostname for email links.

## Email and redirects — pilot mode

Custom SMTP has not yet been configured. During this limited pilot, turn **Confirm email off** in Supabase Authentication → Providers → Email, and set `NEXT_PUBLIC_EMAIL_DELIVERY_ENABLED=false` in Vercel. New password signups then receive a session and proceed directly to onboarding. Addresses are unverified while this mode is active. The site hides reset/resend controls and directs account-recovery requests to `dsnfutminna@datascientistsfoundation.org`; the operator must verify identity before making account changes. Do not advertise email recovery as available.

When a provider is ready, verify the sending domain, configure custom SMTP and test confirmation/recovery delivery to an external address. Set the exact deployment origin as the Site URL and allow `/auth/callback`. Then turn **Confirm email on**, set `NEXT_PUBLIC_EMAIL_DELIVERY_ENABLED=true` in Vercel, redeploy, and test signup, confirmation and password recovery in a new browser session. Existing unverified pilot accounts need a separate verification plan before treating their email addresses as trusted.

Set Supabase Site URL to the deployment's exact origin. Allow its `/auth/callback` redirect and local development callbacks only in the test project.

For links that also work across browsers, configure the confirmation template link as:

```html
<a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=email">Confirm your NEXUS email</a>
```

Configure the recovery template link as:

```html
<a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=recovery">Reset your NEXUS password</a>
```

The application accepts only these two token types and fixed internal destinations. This follows [Supabase's server-side email verification guidance](https://supabase.com/docs/guides/getting-started/tutorials/with-nextjs). Default PKCE callbacks remain supported for same-browser links.

## Feed refresh

First run `python scripts/sync_cloud_feeds.py --dry-run`. For an operator-approved sync, supply `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` through the protected environment. The RPC accepts Remotive, RemoteOK, Jobicy, and vetted Greenhouse/Lever organization boards. Add organizations to `data/opportunity_boards.json` only after verifying their public board and eligibility; the default list is empty. The worker rejects non-HTTPS links and old/expired postings, deduplicates source URLs, hides unrefreshed listings in the UI after 30 days, and deactivates them in the database after 45 days. Review listing geography and source quality before inviting testers.

Seven curated, evergreen learning and leadership programs are seeded from official GitHub Education, AWS Educate, Microsoft Learn, Forage, IBM SkillsBuild, Cisco Networking Academy, and Kaggle pages, each with its own source link. The team should review their eligibility and availability monthly. This curated baseline is separate from the automatically refreshed job feed and must not be described as seven open jobs.

The GitHub workflow uses environment `pilot-feed-sync`, matching secrets and repository variable `NEXUS_FEED_SYNC_ENABLED=true`. It is disabled without that explicit variable. Do not place the credential in source code or web environment variables.

## Real-user acceptance before cutover

1. With pilot mode enabled, register, enter onboarding without an email step, sign in, reload and sign out. Verify account recovery is routed to support. Once SMTP is configured, separately test cross-browser confirmation and password reset before enabling those controls.
2. Complete onboarding using Save and continue; confirm profile and skill ratings persist across sessions.
3. Inspect the roadmap, find a live opportunity, open its source, save it and return to it.
4. Withdraw personalization consent; confirm browsing still works and personalized scores disappear.
5. Submit feedback, reload, and check status. A second student must not see it.
6. Use the designated admin to review the report and add a note. The student sees status but no private note.
7. Test on a real phone and keyboard-only desktop. Record confusion, task completion, usefulness and willingness to return.
8. Publish the pilot contact and retention schedule, verify feed freshness, and confirm the tester invitation schedule.

Existing Streamlit hosting can remain available during acceptance. For the approved no-SMTP pilot, verify direct signup, onboarding, and support-assisted recovery before inviting testers. Before broader release, add reliable SMTP, test email confirmation, and complete hosted permission checks.
