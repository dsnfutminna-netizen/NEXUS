# Pilot retention and deletion operations

Support inbox: **dsnfutminna@datascientistsfoundation.org**. Only staff with Supabase project admin access should perform account deletion. A NEXUS in-app `admin` role can review and triage feedback, but it cannot delete Auth users.

## Monthly inactivity review

Run this read-only query in the Supabase SQL editor once per month. `last_sign_in_at` is the activity marker used in the published policy; accounts that never signed in use `created_at`. Review results before deleting because recent support activity or an unresolved deletion request may need human handling.

```sql
select u.id, u.email,
       coalesce(u.last_sign_in_at, u.created_at) as last_activity,
       p.role
from auth.users u
left join public.profiles p on p.id = u.id
where coalesce(u.last_sign_in_at, u.created_at) < now() - interval '6 months'
order by last_activity;
```

Do not export this list into a public spreadsheet or repository. Check for operator accounts and any account recently contacted by support. Record the review date and outcome in the team's private operations log. Remove inactive student accounts promptly after the six-month threshold; an email provider is not needed for this database operation.

## Individual deletion request

1. Acknowledge the report in the NEXUS admin feedback queue and ask for identity verification through the support inbox if necessary. Do not rely on the account email alone while pilot email confirmation is disabled.
2. Find the exact Auth user ID in Supabase Authentication → Users. Double-check it against the associated profile ID and the request. Do not delete by a shared name or unverified email.
3. Use the Supabase dashboard's **Delete user** control for that ID. The `profiles` foreign key cascades to profile-owned skills, interests, saved opportunities, events, feedback and notes. Check the user and profile no longer exist; handle any residual external copies under the team's retention policy.
4. Record completion in the private operations log and reply to the verified requester. The in-app feedback row disappears when its owner is deleted, so preserve only the minimum administrative audit record outside NEXUS.

Password recovery while SMTP is unavailable is an operator-assisted process. Verify the requester through an independent method before changing credentials. When SMTP is enabled, test the self-service recovery flow and update this runbook.
