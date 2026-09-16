drop policy profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles for insert to authenticated
with check (id=(select auth.uid()) and role='student' and email=(select auth.jwt()->>'email'));
drop policy own_insert on public.events;
create policy own_insert on public.events for insert to authenticated with check
(student_id=(select auth.uid()) and exists(select 1 from public.profiles where id=(select auth.uid()) and data_consent));
