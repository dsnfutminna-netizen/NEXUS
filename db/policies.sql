-- Fresh NEXUS project only. Inspect existing schemas before applying.
-- Shared content is operator-managed. Student clients have no admin capability.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
alter table public.profiles enable row level security;
create policy profiles_select_own on public.profiles for select to authenticated using (id=(select auth.uid()));
create policy profiles_insert_own on public.profiles for insert to authenticated with check (id=(select auth.uid()) and role='student' and email=(select auth.jwt()->>'email'));
create policy profiles_update_own on public.profiles for update to authenticated using (id=(select auth.uid())) with check (id=(select auth.uid()));
grant select on public.profiles to authenticated;
grant insert(id,full_name,email) on public.profiles to authenticated;
grant update(full_name,department_id,level,cgpa,target_career_id,bio,data_consent,consent_at,consent_version) on public.profiles to authenticated;
do $$ declare t text; begin
 foreach t in array array['student_skills','student_interests','experiences','saved_opportunities','recommendations'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy own_rows on public.%I for all to authenticated using (student_id=(select auth.uid())) with check (student_id=(select auth.uid()))',t);
  execute format('grant select,insert,update,delete on public.%I to authenticated',t);
 end loop;
 foreach t in array array['feedback','events','opportunity_interactions'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy own_insert on public.%I for insert to authenticated with check (student_id=(select auth.uid()))',t);
  execute format('create policy own_select on public.%I for select to authenticated using (student_id=(select auth.uid()))',t);
  execute format('grant select,insert on public.%I to authenticated',t);
 end loop;
 foreach t in array array['proficiency_levels','skill_categories','skills','careers','career_required_skills','industries','departments','skill_aliases','opportunity_skills','opportunity_careers','opportunity_departments'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy reference_read on public.%I for select to authenticated using (true)',t);
  execute format('grant select on public.%I to authenticated',t);
 end loop;
end $$;
alter table public.opportunities enable row level security;
create policy active_opportunities on public.opportunities for select to authenticated using (is_active);
grant select on public.opportunities to authenticated;
grant usage on sequence public.feedback_id_seq,public.events_id_seq,public.opportunity_interactions_id_seq to authenticated;
grant select on public.v_skill_gaps,public.v_opportunity_matches,public.v_profile_completeness to authenticated;
create or replace function public.save_my_skills(ratings jsonb) returns void
language plpgsql security invoker set search_path=public as $$
declare item jsonb; caller uuid:=auth.uid(); begin
 if caller is null then raise exception 'Authentication required'; end if;
 if ratings is null or jsonb_typeof(ratings)<>'array' then raise exception 'Expected ratings array'; end if;
 for item in select value from jsonb_array_elements(ratings) loop
  if item->>'rank' is null or (item->>'rank')::integer not between 0 and 4 then raise exception 'Invalid proficiency'; end if;
  if (item->>'rank')::integer=0 then
   delete from student_skills where student_id=caller and skill_id=(item->>'skill_id')::bigint;
  else
   insert into student_skills(student_id,skill_id,proficiency_rank) values(caller,(item->>'skill_id')::bigint,(item->>'rank')::smallint)
   on conflict(student_id,skill_id) do update set proficiency_rank=excluded.proficiency_rank;
  end if;
 end loop;
end $$;
create or replace function public.save_my_interests(industry_ids bigint[]) returns void
language plpgsql security invoker set search_path=public as $$
declare caller uuid:=auth.uid(); begin
 if caller is null then raise exception 'Authentication required'; end if;
 delete from student_interests where student_id=caller;
 insert into student_interests(student_id,industry_id) select caller,id from unnest(industry_ids) as ids(id) on conflict do nothing;
end $$;
revoke execute on function public.save_my_skills(jsonb),public.save_my_interests(bigint[]) from public,anon;
grant execute on function public.save_my_skills(jsonb),public.save_my_interests(bigint[]) to authenticated;
revoke execute on function public.set_updated_at() from public,anon,authenticated;

-- Consent governs analytics inserts even through direct API requests.
drop policy own_insert on public.events;
create policy own_insert on public.events for insert to authenticated with check (student_id=(select auth.uid()) and exists(select 1 from public.profiles where id=(select auth.uid()) and data_consent));
grant usage on sequence public.recommendations_id_seq to authenticated;
