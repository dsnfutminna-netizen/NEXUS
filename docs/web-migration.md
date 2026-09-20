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

For an empty project, apply every file in `supabase/migrations` in timestamp order. For the existing pilot, apply only migrations that are absent from its migration history. Seed reference data using the repository's existing import tooling.

New migrations add feedback tables and policies, an admin role check, private review notes, and an operator-only feed upsert function. They do not delete or replace existing student data. Assign an administrator through a trusted database operator after verifying the user's identity; signup metadata must never grant roles.

Run existing `db/test_rls.sql` and `db/test_identity_consent.sql` in the test project. Complete hosted feedback isolation checks with two student accounts and one operator-designated admin. Local PGlite checks complement this step.

## Vercel setup

Import the NEXUS GitHub repository, select the reviewed migration branch, set root directory **web**, and use the Next.js preset with Node.js 24. Set:

| Variable | Value |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Test project URL for preview; approved pilot project for production |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Matching project's publishable key |
| `NEXT_PUBLIC_SITE_URL` | Exact stable HTTPS origin of this deployment |

Never enter a service-role key into a `NEXT_PUBLIC_` variable. Environment changes require a fresh build. Keep production and preview variables separate, and use a stable test hostname for email links.

## Email and redirects — launch dependency

Custom SMTP has not yet been configured. Choose an email provider and verify a domain under the owner's control. Enter SMTP credentials directly in Supabase, configure sender identity and DNS, and verify delivery to real tester inboxes. Keep email confirmation enabled.

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

First run `python scripts/sync_cloud_feeds.py --dry-run`. For an operator-approved sync, supply `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` through the protected environment. The RPC accepts only Remotive and RemoteOK listings. Review listing freshness and source quality before inviting testers.

The GitHub workflow uses environment `pilot-feed-sync`, matching secrets and repository variable `NEXUS_FEED_SYNC_ENABLED=true`. It is disabled without that explicit variable. Do not place the credential in source code or web environment variables.

## Real-user acceptance before cutover

1. Register, receive email, confirm in a second browser, sign in, reload, sign out, and reset a password.
2. Complete onboarding using Save and continue; confirm profile and skill ratings persist across sessions.
3. Inspect the roadmap, find a live opportunity, open its source, save it and return to it.
4. Withdraw personalization consent; confirm browsing still works and personalized scores disappear.
5. Submit feedback, reload, and check status. A second student must not see it.
6. Use the designated admin to review the report and add a note. The student sees status but no private note.
7. Test on a real phone and keyboard-only desktop. Record confusion, task completion, usefulness and willingness to return.
8. Publish the pilot contact and retention schedule, verify feed freshness, and confirm the tester invitation schedule.

Existing Streamlit hosting can remain available during acceptance. Do not announce the web app as live until the deployed build, real email flow and hosted permissions pass.
