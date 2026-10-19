-- Optional pilot-outcome questions. Keep contact permission independent.
alter table public.feedback_requests
  add column clarity_before smallint check (clarity_before between 1 and 5),
  add column clarity_after smallint check (clarity_after between 1 and 5),
  add column recommend_score smallint check (recommend_score between 0 and 10);
grant insert(clarity_before, clarity_after, recommend_score) on public.feedback_requests to authenticated;

create or replace function public.admin_metrics() returns jsonb
language sql stable security definer set search_path=public as $$
  select case when public.is_pilot_admin() then jsonb_build_object(
    'students',  (select count(*) from public.profiles where role='student'),
    'onboarded', (select count(*) from public.profiles where role='student' and target_career_id is not null),
    'consented', (select count(*) from public.profiles where role='student' and data_consent),
    'saves',     (select count(*) from public.saved_opportunities),
    'events',    (select count(*) from public.events),
    'feedback_responses', (select count(*) from public.feedback_requests),
    'clarity_change', (select round(avg(clarity_after - clarity_before)::numeric, 1) from public.feedback_requests where clarity_before is not null and clarity_after is not null),
    'nps', (select round(100.0 * (count(*) filter (where recommend_score >= 9) - count(*) filter (where recommend_score <= 6)) / nullif(count(*),0)) from public.feedback_requests where recommend_score is not null)
  ) else '{}'::jsonb end
$$;
revoke all on function public.admin_metrics() from public, anon;
grant execute on function public.admin_metrics() to authenticated;

-- Called only by the privileged ingestion worker, never by a student browser.
create or replace function public.sync_feed_opportunities(postings jsonb) returns integer
language plpgsql security invoker set search_path=public as $$
declare posting jsonb; tag jsonb; career text; oid uuid; total integer:=0;
begin
 if coalesce(jsonb_typeof(postings),'null')<>'array' or jsonb_array_length(postings)>500 then raise exception 'Expected at most 500 postings'; end if;
 for posting in select value from jsonb_array_elements(postings) loop
  if coalesce(posting->>'source','') not in ('remotive','remoteok','jobicy','greenhouse','lever') or coalesce(posting->>'external_id','')='' then raise exception 'Invalid feed identity'; end if;
  if coalesce(posting->>'url','') !~ '^https://[^/]+/' then raise exception 'HTTPS source URL required'; end if;
  insert into opportunities(slug,title,category,organization,description,url,location,is_remote,source,external_id,posted_at,deadline,fetched_at,tags,is_active)
  values(posting->>'slug',posting->>'title',(posting->>'category')::opportunity_category,posting->>'organization',posting->>'description',posting->>'url',posting->>'location',coalesce((posting->>'is_remote')::boolean,false),posting->>'source',posting->>'external_id',nullif(posting->>'posted_at','')::timestamptz,nullif(posting->>'deadline','')::date,now(),(posting->'tags')::text,true)
  on conflict(source,external_id) where external_id is not null do update set title=excluded.title,category=excluded.category,organization=excluded.organization,description=excluded.description,url=excluded.url,location=excluded.location,is_remote=excluded.is_remote,posted_at=excluded.posted_at,deadline=excluded.deadline,fetched_at=now(),tags=excluded.tags,is_active=true
  returning id into oid;
  delete from opportunity_skills where opportunity_id=oid;
  for tag in select value from jsonb_array_elements(posting->'skill_tags') loop
   insert into opportunity_skills(opportunity_id,skill_id,weight) select oid,id,(tag->>'weight')::smallint from skills where slug=tag->>'slug';
  end loop;
  delete from opportunity_careers where opportunity_id=oid;
  for career in select jsonb_array_elements_text(posting->'career_tags') loop
   insert into opportunity_careers(opportunity_id,career_id) select oid,id from careers where slug=career;
  end loop;
  total:=total+1;
 end loop;
 -- A source may disappear temporarily. Hide only posts that have not been
 -- refreshed for 45 days; a later refresh can reactivate them.
 update public.opportunities set is_active=false
 where source in ('remotive','remoteok','jobicy','greenhouse','lever')
   and is_active and fetched_at < now() - interval '45 days';
 return total;
end $$;
revoke all on function public.sync_feed_opportunities(jsonb) from public,anon,authenticated;
grant execute on function public.sync_feed_opportunities(jsonb) to service_role;
