-- Additive. Admin-only aggregate metrics for the pilot dashboard.
-- Security definer so counts bypass per-row RLS, but every branch is gated by
-- is_pilot_admin() (which reads the CALLER's profile via auth.uid(), not the
-- function owner), so a non-admin caller always receives an empty object.
create or replace function public.admin_metrics() returns jsonb
language sql stable security definer set search_path=public as $$
  select case when public.is_pilot_admin() then jsonb_build_object(
    'students',  (select count(*) from public.profiles where role='student'),
    'onboarded', (select count(*) from public.profiles where role='student' and target_career_id is not null),
    'consented', (select count(*) from public.profiles where role='student' and data_consent),
    'saves',     (select count(*) from public.saved_opportunities),
    'events',    (select count(*) from public.events)
  ) else '{}'::jsonb end
$$;
revoke all on function public.admin_metrics() from public, anon;
grant execute on function public.admin_metrics() to authenticated;
