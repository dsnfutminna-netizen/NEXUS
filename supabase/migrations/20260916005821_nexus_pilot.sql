-- =====================================================================
-- NEXUS — Database Schema (v1)
-- DSN FUTMinna Student Intelligence & Opportunity Platform
--
-- Target:   PostgreSQL 15+  (designed for Supabase)
-- Run with: psql < schema.sql       (then seed.sql, then policies.sql)
--
-- Design principles
--   1. Fixed taxonomies (skills, careers, proficiency) live in their own
--      tables so matching is reliable — never free text.
--   2. Proficiency is a numeric rank (0..4) so gaps are simple subtraction.
--   3. The "answer key" (career_required_skills) is real data, curated by
--      humans. The intelligence layer is just SQL over it (see views).
--   4. Every table that stores student data is privacy-scoped by RLS
--      (see policies.sql).
-- =====================================================================

create extension if not exists pgcrypto;   -- for gen_random_uuid()

-- ---------------------------------------------------------------------
-- ENUMS
-- ---------------------------------------------------------------------
create type user_role            as enum ('student', 'contributor', 'admin');
create type experience_type      as enum ('project','competition','internship',
                                          'volunteering','leadership','certification','work');
create type opportunity_category as enum ('internship','scholarship','fellowship','hackathon',
                                          'competition','research','conference','training',
                                          'certification','volunteering','leadership','job');
create type interaction_type     as enum ('view','save','unsave','click_apply','dismiss');

-- =====================================================================
-- SECTION 1 — REFERENCE / TAXONOMY  (the shared vocabulary)
-- =====================================================================

-- Proficiency scale. Numeric rank makes gap analysis trivial arithmetic.
create table proficiency_levels (
  rank        smallint primary key,          -- 0..4
  code        text unique not null,
  label       text not null,
  description text
);

create table skill_categories (
  id          bigint generated always as identity primary key,
  name        text unique not null,
  description text
);

create table skills (
  id          bigint generated always as identity primary key,
  name        text unique not null,
  slug        text unique not null,          -- stable key used by seeds/app
  category_id bigint not null references skill_categories(id),
  description text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);
create index idx_skills_category on skills(category_id);

create table careers (
  id          bigint generated always as identity primary key,
  name        text unique not null,
  slug        text unique not null,
  description text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- THE ANSWER KEY: for each career, which skills at what target level.
-- weight: 3 = core, 2 = important, 1 = nice-to-have.
create table career_required_skills (
  career_id   bigint   not null references careers(id) on delete cascade,
  skill_id    bigint   not null references skills(id)  on delete cascade,
  target_rank smallint not null references proficiency_levels(rank),
  weight      smallint not null default 2 check (weight between 1 and 3),
  primary key (career_id, skill_id)
);
create index idx_crs_skill on career_required_skills(skill_id);

create table industries (
  id   bigint generated always as identity primary key,
  name text unique not null
);

create table departments (
  id      bigint generated always as identity primary key,
  name    text unique not null,
  faculty text
);

-- =====================================================================
-- SECTION 2 — STUDENT PROFILE
-- =====================================================================

create table profiles (
  id               uuid primary key references auth.users(id) on delete cascade,
  full_name        text not null,
  email            text unique not null,
  role             user_role not null default 'student',

  -- academic profile (CGPA on the Nigerian 5.00 scale used by FUTMinna)
  department_id    bigint references departments(id),
  level            smallint check (level in (100,200,300,400,500,600,700)),
  cgpa             numeric(3,2) check (cgpa >= 0 and cgpa <= 5.00),

  -- goal that drives gap analysis + matching
  target_career_id bigint references careers(id),
  bio              text,

  -- consent / privacy (see docs/ — data handling is a foundational requirement)
  data_consent     boolean not null default false,
  consent_at       timestamptz,
  consent_version  text,

  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_profiles_department on profiles(department_id);
create index idx_profiles_target     on profiles(target_career_id);

create table student_skills (
  student_id       uuid     not null references profiles(id) on delete cascade,
  skill_id         bigint   not null references skills(id)   on delete cascade,
  proficiency_rank smallint not null references proficiency_levels(rank),
  self_assessed    boolean  not null default true,
  updated_at       timestamptz not null default now(),
  primary key (student_id, skill_id)
);
create index idx_student_skills_skill on student_skills(skill_id);

create table student_interests (
  student_id  uuid   not null references profiles(id)   on delete cascade,
  industry_id bigint not null references industries(id) on delete cascade,
  primary key (student_id, industry_id)
);

create table experiences (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references profiles(id) on delete cascade,
  type         experience_type not null,
  title        text not null,
  organization text,
  description  text,
  url          text,
  start_date   date,
  end_date     date,
  is_ongoing   boolean not null default false,
  created_at   timestamptz not null default now()
);
create index idx_experiences_student on experiences(student_id);

-- =====================================================================
-- SECTION 3 — OPPORTUNITIES
-- =====================================================================

create table opportunities (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  slug         text unique,
  category     opportunity_category not null,
  organization text,
  description  text,
  url          text,
  location     text,
  is_remote    boolean not null default false,

  -- eligibility (null = no restriction)
  min_level    smallint check (min_level in (100,200,300,400,500,600,700)),
  max_level    smallint check (max_level in (100,200,300,400,500,600,700)),
  deadline     date,

  is_active    boolean not null default true,
  source       text,
  external_id  text,
  posted_at    timestamptz,
  fetched_at   timestamptz,
  tags         text,
  created_by   uuid references profiles(id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index idx_opportunities_category on opportunities(category);
create index idx_opportunities_active   on opportunities(is_active);
create index idx_opportunities_deadline on opportunities(deadline);

-- Skills an opportunity calls for (drives the match score).
create table opportunity_skills (
  opportunity_id uuid   references opportunities(id) on delete cascade,
  skill_id       bigint references skills(id)        on delete cascade,
  weight         smallint not null default 2 check (weight between 1 and 3),
  primary key (opportunity_id, skill_id)
);
create index idx_opp_skills_skill on opportunity_skills(skill_id);

-- Career pathways an opportunity aligns with (boosts match for that goal).
create table opportunity_careers (
  opportunity_id uuid   references opportunities(id) on delete cascade,
  career_id      bigint references careers(id)       on delete cascade,
  primary key (opportunity_id, career_id)
);

-- Department eligibility. No rows = open to all departments.
create table opportunity_departments (
  opportunity_id uuid   references opportunities(id) on delete cascade,
  department_id  bigint references departments(id)   on delete cascade,
  primary key (opportunity_id, department_id)
);

-- =====================================================================
-- SECTION 4 — ENGAGEMENT & ANALYTICS  (needed to VALIDATE the pilot)
-- =====================================================================

create table saved_opportunities (
  student_id     uuid references profiles(id)      on delete cascade,
  opportunity_id uuid references opportunities(id) on delete cascade,
  created_at     timestamptz not null default now(),
  primary key (student_id, opportunity_id)
);

create table opportunity_interactions (
  id             bigint generated always as identity primary key,
  student_id     uuid references profiles(id)      on delete set null,
  opportunity_id uuid references opportunities(id) on delete cascade,
  action         interaction_type not null,
  created_at     timestamptz not null default now()
);
create index idx_opp_int_opp     on opportunity_interactions(opportunity_id);
create index idx_opp_int_student on opportunity_interactions(student_id);

-- Generic event log — the backbone of usage metrics (logins, profile_completed,
-- gap_viewed, recommendation_viewed, etc.). Schema-light on purpose.
create table events (
  id          bigint generated always as identity primary key,
  student_id  uuid references profiles(id) on delete set null,
  event_type  text not null,
  entity_type text,
  entity_id   text,
  metadata    jsonb not null default '{}',
  created_at  timestamptz not null default now()
);
create index idx_events_type    on events(event_type);
create index idx_events_student on events(student_id);
create index idx_events_created on events(created_at);

-- Captures the headline validation metric: clarity before vs after + NPS.
create table feedback (
  id             bigint generated always as identity primary key,
  student_id     uuid references profiles(id) on delete set null,
  clarity_before smallint check (clarity_before between 1 and 5),
  clarity_after  smallint check (clarity_after  between 1 and 5),
  nps            smallint check (nps between 0 and 10),
  most_useful    text,
  improvement    text,
  comment        text,
  created_at     timestamptz not null default now()
);

-- Optional: stored/curated recommendations (v1 can also derive these live).
create table recommendations (
  id         bigint generated always as identity primary key,
  student_id uuid not null references profiles(id) on delete cascade,
  skill_id   bigint references skills(id),
  title      text not null,
  detail     text,
  priority   smallint not null default 2,
  is_done    boolean not null default false,
  created_at timestamptz not null default now()
);
create index idx_recommendations_student on recommendations(student_id);

-- =====================================================================
-- SECTION 5 — TRIGGERS
-- =====================================================================
create or replace function set_updated_at() returns trigger
language plpgsql set search_path = public as $$
begin new.updated_at = now(); return new; end;
$$;

create trigger trg_profiles_updated      before update on profiles
  for each row execute function set_updated_at();
create trigger trg_opportunities_updated before update on opportunities
  for each row execute function set_updated_at();
create trigger trg_student_skills_updated before update on student_skills
  for each row execute function set_updated_at();

-- =====================================================================
-- SECTION 6 — INTELLIGENCE VIEWS  (this is where NEXUS earns its name)
--   These implement the doc's examples as transparent, rule-based SQL.
-- =====================================================================

-- 6a. SKILL-GAP ANALYSIS — one row per (student, required skill for their goal).
--     Reproduces the doc's gap table: Current vs Desired vs Gap.
create or replace view v_skill_gaps with (security_invoker = true) as
select
  p.id                                                           as student_id,
  c.id                                                           as career_id,
  c.name                                                         as career_name,
  sk.id                                                          as skill_id,
  sk.name                                                        as skill_name,
  crs.weight                                                     as importance,      -- 3 core .. 1 nice
  crs.target_rank,
  coalesce(ss.proficiency_rank, 0)                               as current_rank,
  greatest(crs.target_rank - coalesce(ss.proficiency_rank,0), 0) as gap,
  case
    when crs.target_rank - coalesce(ss.proficiency_rank,0) <= 0 then 'On track'
    when crs.target_rank - coalesce(ss.proficiency_rank,0) =  1 then 'Low'
    when crs.target_rank - coalesce(ss.proficiency_rank,0) =  2 then 'Medium'
    else 'High'
  end                                                            as gap_label,
  -- what to fix first = biggest gap on the most important skills
  greatest(crs.target_rank - coalesce(ss.proficiency_rank,0),0) * crs.weight as priority
from profiles p
join careers                c   on c.id  = p.target_career_id
join career_required_skills crs on crs.career_id = c.id
join skills                 sk  on sk.id = crs.skill_id
left join student_skills    ss  on ss.student_id = p.id and ss.skill_id = crs.skill_id;

-- 6b. OPPORTUNITY MATCHING — one row per (student, active opportunity).
--     Transparent score: 65% skills + 20% career alignment + 15% eligibility.
--     `matched_skills` gives the "why it matches" bullet list from the doc.
create or replace view v_opportunity_matches with (security_invoker = true) as
with opp_totals as (
  select opportunity_id, sum(weight)::numeric as total_weight
  from opportunity_skills
  group by opportunity_id
),
sos as (   -- student-vs-opportunity skill overlap
  select
    p.id                                                    as student_id,
    os.opportunity_id,
    (sum(os.weight) filter (where ss.skill_id is not null))::numeric as matched_weight,
    array_agg(sk.name order by os.weight desc, sk.name)
      filter (where ss.skill_id is not null)                as matched_skills
  from profiles p
  cross join opportunity_skills os
  join skills sk on sk.id = os.skill_id
  left join student_skills ss
    on ss.student_id = p.id and ss.skill_id = os.skill_id and ss.proficiency_rank >= 1
  group by p.id, os.opportunity_id
),
base as (
  select
    sos.student_id,
    sos.opportunity_id,
    o.title,
    o.category,
    o.deadline,
    coalesce(sos.matched_skills, array[]::text[])                       as matched_skills,
    coalesce(coalesce(sos.matched_weight,0) / nullif(ot.total_weight,0), 0) as skill_ratio,
    ((o.min_level is null or p.level >= o.min_level)
      and (o.max_level is null or p.level <= o.max_level))              as level_ok,
    (not exists (select 1 from opportunity_departments od where od.opportunity_id = o.id)
      or exists (select 1 from opportunity_departments od
                 where od.opportunity_id = o.id and od.department_id = p.department_id)) as dept_ok,
    case
      when not exists (select 1 from opportunity_careers oc where oc.opportunity_id = o.id) then 0.5
      when exists (select 1 from opportunity_careers oc
                   where oc.opportunity_id = o.id and oc.career_id = p.target_career_id) then 1.0
      else 0.0
    end                                                                 as career_align
  from sos
  join opportunities o on o.id = sos.opportunity_id and o.is_active
  join opp_totals    ot on ot.opportunity_id = o.id
  join profiles      p  on p.id = sos.student_id
)
select
  student_id,
  opportunity_id,
  title,
  category,
  deadline,
  round(100 * skill_ratio)                                       as skill_match_pct,
  matched_skills,
  (level_ok and dept_ok)                                         as is_eligible,
  round(100 * (0.65 * skill_ratio
             + 0.20 * career_align
             + 0.15 * ((level_ok and dept_ok))::int))::int       as match_score
from base;

-- 6c. PROFILE COMPLETENESS — the pilot metric "profile completion rate".
create or replace view v_profile_completeness with (security_invoker = true) as
select
  p.id as student_id,
  round(100.0 * (
      (case when p.department_id    is not null then 1 else 0 end)
    + (case when p.level            is not null then 1 else 0 end)
    + (case when p.cgpa             is not null then 1 else 0 end)
    + (case when p.target_career_id is not null then 1 else 0 end)
    + (case when (select count(*) from student_skills ss where ss.student_id = p.id) >= 3 then 1 else 0 end)
    + (case when exists (select 1 from student_interests si where si.student_id = p.id) then 1 else 0 end)
  ) / 6.0, 0) as completeness_pct
from profiles p;

-- ---------------------------------------------------------------------
comment on view v_skill_gaps          is 'Skill-gap analysis for each student vs their target career (doc: gap table).';
comment on view v_opportunity_matches is 'Rule-based opportunity match score + reasons (doc: 88% match example).';
comment on view v_profile_completeness is 'Profile completion % — pilot validation metric.';
-- =====================================================================
-- Next: run seed.sql (taxonomy + 5 careers), then policies.sql (Supabase RLS).
-- =====================================================================

-- Aliases used by the pilot's current text tagger.
create table skill_aliases (
  skill_id bigint not null references skills(id) on delete cascade,
  alias text not null,
  primary key (skill_id, alias)
);
create unique index ux_opps_source_external on opportunities(source, external_id)
  where external_id is not null;


-- Fresh NEXUS project only. Inspect existing schemas before applying.
-- Shared content is operator-managed. Student clients have no admin capability.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
alter table public.profiles enable row level security;
create policy profiles_select_own on public.profiles for select to authenticated using (id=(select auth.uid()));
create policy profiles_insert_own on public.profiles for insert to authenticated with check (id=(select auth.uid()) and role='student');
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


-- Generated by scripts/build_cloud_seed.py. Public reference data only.
insert into proficiency_levels (rank,code,label,description) values ('0','none','None','No exposure yet.') on conflict do nothing;
insert into proficiency_levels (rank,code,label,description) values ('1','beginner','Beginner','Basic awareness; needs guidance.') on conflict do nothing;
insert into proficiency_levels (rank,code,label,description) values ('2','intermediate','Intermediate','Can work on tasks with some support.') on conflict do nothing;
insert into proficiency_levels (rank,code,label,description) values ('3','advanced','Advanced','Works independently; can guide others.') on conflict do nothing;
insert into proficiency_levels (rank,code,label,description) values ('4','expert','Expert','Deep expertise; the go-to person.') on conflict do nothing;
insert into industries (name) values ('Technology & Software') on conflict do nothing;
insert into industries (name) values ('Financial Services & Fintech') on conflict do nothing;
insert into industries (name) values ('Healthcare & HealthTech') on conflict do nothing;
insert into industries (name) values ('Education & EdTech') on conflict do nothing;
insert into industries (name) values ('Agriculture & AgriTech') on conflict do nothing;
insert into industries (name) values ('E-commerce & Retail') on conflict do nothing;
insert into industries (name) values ('Telecommunications') on conflict do nothing;
insert into industries (name) values ('Energy & Power') on conflict do nothing;
insert into industries (name) values ('Government & Public Sector') on conflict do nothing;
insert into industries (name) values ('Media & Entertainment') on conflict do nothing;
insert into industries (name) values ('Consulting & Professional Services') on conflict do nothing;
insert into industries (name) values ('Manufacturing') on conflict do nothing;
insert into industries (name) values ('Transportation & Logistics') on conflict do nothing;
insert into industries (name) values ('Nonprofit & Social Impact') on conflict do nothing;
insert into departments (name,faculty) values ('Computer Science','SICT') on conflict do nothing;
insert into departments (name,faculty) values ('Cyber Security Science','SICT') on conflict do nothing;
insert into departments (name,faculty) values ('Information Technology','SICT') on conflict do nothing;
insert into departments (name,faculty) values ('Information and Media Technology','SICT') on conflict do nothing;
insert into departments (name,faculty) values ('Library and Information Technology','SICT') on conflict do nothing;
insert into departments (name,faculty) values ('Mathematics','SPS') on conflict do nothing;
insert into departments (name,faculty) values ('Statistics','SPS') on conflict do nothing;
insert into departments (name,faculty) values ('Physics','SPS') on conflict do nothing;
insert into departments (name,faculty) values ('Chemistry','SPS') on conflict do nothing;
insert into departments (name,faculty) values ('Geology','SPS') on conflict do nothing;
insert into departments (name,faculty) values ('Biological Sciences','SPS') on conflict do nothing;
insert into departments (name,faculty) values ('Biochemistry','SPS') on conflict do nothing;
insert into departments (name,faculty) values ('Electrical and Electronics Engineering','SEET') on conflict do nothing;
insert into departments (name,faculty) values ('Computer Engineering','SEET') on conflict do nothing;
insert into departments (name,faculty) values ('Telecommunication Engineering','SEET') on conflict do nothing;
insert into departments (name,faculty) values ('Mechatronics Engineering','SEET') on conflict do nothing;
insert into skill_categories (name) values ('Data & Analytics') on conflict do nothing;
insert into skill_categories (name) values ('Design & UX') on conflict do nothing;
insert into skill_categories (name) values ('Machine Learning & AI') on conflict do nothing;
insert into skill_categories (name) values ('Marketing & Growth') on conflict do nothing;
insert into skill_categories (name) values ('Professional & Soft Skills') on conflict do nothing;
insert into skill_categories (name) values ('Programming & Software Engineering') on conflict do nothing;
insert into skill_categories (name) values ('Tools & Platforms') on conflict do nothing;
insert into skills (name,slug,category_id) values ('Python','python',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('JavaScript','javascript',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('TypeScript','typescript',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Java','java',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('C++','cpp',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('SQL','sql',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('HTML & CSS','html-css',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('React','react',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Node.js','nodejs',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Git & Version Control','git',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('REST APIs','rest-apis',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Relational Databases','relational-databases',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Software Testing','software-testing',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('System Design','system-design',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Object-Oriented Programming','oop',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Data Structures & Algorithms','dsa',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Mobile Development','mobile-development',(select id from skill_categories where name='Programming & Software Engineering')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Statistics','statistics',(select id from skill_categories where name='Data & Analytics')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Data Analysis','data-analysis',(select id from skill_categories where name='Data & Analytics')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Data Visualization','data-visualization',(select id from skill_categories where name='Data & Analytics')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Spreadsheets (Excel/Sheets)','spreadsheets',(select id from skill_categories where name='Data & Analytics')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Data Cleaning & Wrangling','data-cleaning',(select id from skill_categories where name='Data & Analytics')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Exploratory Data Analysis','eda',(select id from skill_categories where name='Data & Analytics')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Business Intelligence (Power BI/Tableau)','business-intelligence',(select id from skill_categories where name='Data & Analytics')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Data Storytelling','data-storytelling',(select id from skill_categories where name='Data & Analytics')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('A/B Testing & Experimentation','ab-testing',(select id from skill_categories where name='Data & Analytics')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Machine Learning','machine-learning',(select id from skill_categories where name='Machine Learning & AI')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Deep Learning','deep-learning',(select id from skill_categories where name='Machine Learning & AI')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Natural Language Processing','nlp',(select id from skill_categories where name='Machine Learning & AI')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Computer Vision','computer-vision',(select id from skill_categories where name='Machine Learning & AI')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Model Deployment & MLOps','mlops',(select id from skill_categories where name='Machine Learning & AI')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Feature Engineering','feature-engineering',(select id from skill_categories where name='Machine Learning & AI')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Model Evaluation','model-evaluation',(select id from skill_categories where name='Machine Learning & AI')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('PyTorch / TensorFlow','dl-frameworks',(select id from skill_categories where name='Machine Learning & AI')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Large Language Models','llms',(select id from skill_categories where name='Machine Learning & AI')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Prompt Engineering','prompt-engineering',(select id from skill_categories where name='Machine Learning & AI')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Generative AI','generative-ai',(select id from skill_categories where name='Machine Learning & AI')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('UI Design','ui-design',(select id from skill_categories where name='Design & UX')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('UX Research','ux-research',(select id from skill_categories where name='Design & UX')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Wireframing & Prototyping','wireframing',(select id from skill_categories where name='Design & UX')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Figma','figma',(select id from skill_categories where name='Design & UX')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Design Systems','design-systems',(select id from skill_categories where name='Design & UX')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Interaction Design','interaction-design',(select id from skill_categories where name='Design & UX')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Usability Testing','usability-testing',(select id from skill_categories where name='Design & UX')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Information Architecture','information-architecture',(select id from skill_categories where name='Design & UX')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Visual & Graphic Design','visual-design',(select id from skill_categories where name='Design & UX')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('User Journey Mapping','user-journey-mapping',(select id from skill_categories where name='Design & UX')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Digital Marketing','digital-marketing',(select id from skill_categories where name='Marketing & Growth')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Content Marketing','content-marketing',(select id from skill_categories where name='Marketing & Growth')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('SEO','seo',(select id from skill_categories where name='Marketing & Growth')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Social Media Marketing','social-media-marketing',(select id from skill_categories where name='Marketing & Growth')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Email Marketing','email-marketing',(select id from skill_categories where name='Marketing & Growth')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Copywriting','copywriting',(select id from skill_categories where name='Marketing & Growth')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Paid Advertising (Google/Meta Ads)','paid-advertising',(select id from skill_categories where name='Marketing & Growth')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Marketing Analytics','marketing-analytics',(select id from skill_categories where name='Marketing & Growth')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Google Analytics','google-analytics',(select id from skill_categories where name='Marketing & Growth')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Brand Strategy','brand-strategy',(select id from skill_categories where name='Marketing & Growth')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('CRM Tools','crm-tools',(select id from skill_categories where name='Marketing & Growth')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Jupyter Notebooks','jupyter',(select id from skill_categories where name='Tools & Platforms')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Cloud Platforms (AWS/GCP/Azure)','cloud-platforms',(select id from skill_categories where name='Tools & Platforms')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Docker','docker',(select id from skill_categories where name='Tools & Platforms')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Linux & Command Line','linux-cli',(select id from skill_categories where name='Tools & Platforms')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Communication','communication',(select id from skill_categories where name='Professional & Soft Skills')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Teamwork & Collaboration','teamwork',(select id from skill_categories where name='Professional & Soft Skills')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Problem Solving','problem-solving',(select id from skill_categories where name='Professional & Soft Skills')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Critical Thinking','critical-thinking',(select id from skill_categories where name='Professional & Soft Skills')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Leadership','leadership',(select id from skill_categories where name='Professional & Soft Skills')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Project Management','project-management',(select id from skill_categories where name='Professional & Soft Skills')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Presentation Skills','presentation-skills',(select id from skill_categories where name='Professional & Soft Skills')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Time Management','time-management',(select id from skill_categories where name='Professional & Soft Skills')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Stakeholder Management','stakeholder-management',(select id from skill_categories where name='Professional & Soft Skills')) on conflict do nothing;
insert into skills (name,slug,category_id) values ('Adaptability','adaptability',(select id from skill_categories where name='Professional & Soft Skills')) on conflict do nothing;
insert into careers (name,slug,description) values ('Data Scientist','data-scientist','Turns data into insight and predictive models using statistics, Python and ML.') on conflict do nothing;
insert into careers (name,slug,description) values ('AI Engineer','ai-engineer','Builds, deploys and scales machine-learning and AI systems in production.') on conflict do nothing;
insert into careers (name,slug,description) values ('Software Developer','software-developer','Designs and builds reliable software applications and services.') on conflict do nothing;
insert into careers (name,slug,description) values ('Product Designer','product-designer','Researches users and designs usable, valuable product experiences.') on conflict do nothing;
insert into careers (name,slug,description) values ('Digital Marketer','digital-marketer','Grows audiences and conversions across digital channels using data.') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='python'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='statistics'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='machine-learning'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='data-analysis'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='sql'),'2','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='data-cleaning'),'3','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='data-visualization'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='eda'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='feature-engineering'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='model-evaluation'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='data-storytelling'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='communication'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='jupyter'),'2','1') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='git'),'2','1') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='data-scientist'),(select id from skills where slug='deep-learning'),'1','1') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='python'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='machine-learning'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='deep-learning'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='dl-frameworks'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='mlops'),'2','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='nlp'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='llms'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='dsa'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='rest-apis'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='docker'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='cloud-platforms'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='model-evaluation'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='git'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='communication'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='generative-ai'),'2','1') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='prompt-engineering'),'2','1') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='ai-engineer'),(select id from skills where slug='sql'),'1','1') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='dsa'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='oop'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='git'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='javascript'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='problem-solving'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='rest-apis'),'2','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='relational-databases'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='sql'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='software-testing'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='system-design'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='react'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='nodejs'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='html-css'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='communication'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='teamwork'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='docker'),'1','1') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='software-developer'),(select id from skills where slug='cloud-platforms'),'1','1') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='ui-design'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='ux-research'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='figma'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='wireframing'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='communication'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='design-systems'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='interaction-design'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='usability-testing'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='user-journey-mapping'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='information-architecture'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='visual-design'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='presentation-skills'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='stakeholder-management'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='product-designer'),(select id from skills where slug='problem-solving'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='digital-marketing'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='content-marketing'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='social-media-marketing'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='communication'),'3','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='seo'),'2','3') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='copywriting'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='email-marketing'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='paid-advertising'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='marketing-analytics'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='google-analytics'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='brand-strategy'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='presentation-skills'),'2','2') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='crm-tools'),'2','1') on conflict do nothing;
insert into career_required_skills (career_id,skill_id,target_rank,weight) values ((select id from careers where slug='digital-marketer'),(select id from skills where slug='data-analysis'),'1','1') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='javascript'),'js') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='javascript'),'ecmascript') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='typescript'),'type script') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='cpp'),'c++') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='cpp'),'cplusplus') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='sql'),'structured query language') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='sql'),'t-sql') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='sql'),'pl/sql') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='html-css'),'html') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='html-css'),'css') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='html-css'),'html5') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='html-css'),'css3') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='react'),'reactjs') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='react'),'react.js') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='react'),'react js') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='nodejs'),'node.js') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='nodejs'),'nodejs') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='nodejs'),'node js') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='git'),'github') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='git'),'gitlab') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='git'),'version control') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='git'),'source control') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='rest-apis'),'restful') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='rest-apis'),'rest api') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='rest-apis'),'restful api') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='rest-apis'),'api development') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='relational-databases'),'postgresql') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='relational-databases'),'postgres') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='relational-databases'),'mysql') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='relational-databases'),'mariadb') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='relational-databases'),'rdbms') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='relational-databases'),'relational database') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='software-testing'),'unit testing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='software-testing'),'test automation') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='software-testing'),'pytest') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='software-testing'),'jest') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='software-testing'),'selenium') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='software-testing'),'tdd') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='system-design'),'system design') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='system-design'),'distributed systems') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='system-design'),'microservices') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='system-design'),'scalability') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='oop'),'object-oriented') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='oop'),'object oriented') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='dsa'),'data structures') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='dsa'),'algorithms') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='dsa'),'data structures and algorithms') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='mobile-development'),'android') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='mobile-development'),'ios') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='mobile-development'),'react native') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='mobile-development'),'flutter') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='mobile-development'),'mobile app') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='statistics'),'statistical') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='statistics'),'hypothesis testing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='statistics'),'probability') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='data-analysis'),'data analysis') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='data-analysis'),'data analyst') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='data-visualization'),'data visualization') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='data-visualization'),'data viz') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='data-visualization'),'matplotlib') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='data-visualization'),'seaborn') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='data-visualization'),'plotly') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='spreadsheets'),'ms excel') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='spreadsheets'),'google sheets') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='spreadsheets'),'microsoft excel') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='data-cleaning'),'data cleaning') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='data-cleaning'),'data wrangling') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='data-cleaning'),'data preprocessing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='data-cleaning'),'etl') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='eda'),'exploratory data analysis') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='business-intelligence'),'power bi') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='business-intelligence'),'powerbi') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='business-intelligence'),'tableau') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='business-intelligence'),'looker') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='business-intelligence'),'business intelligence') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='data-storytelling'),'data storytelling') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='data-storytelling'),'storytelling with data') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='ab-testing'),'a/b testing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='ab-testing'),'ab testing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='ab-testing'),'experimentation') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='machine-learning'),'machine learning') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='machine-learning'),'ml') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='machine-learning'),'scikit-learn') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='machine-learning'),'sklearn') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='machine-learning'),'scikit learn') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='machine-learning'),'supervised learning') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='machine-learning'),'predictive modeling') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='deep-learning'),'deep learning') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='deep-learning'),'neural network') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='deep-learning'),'neural networks') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='deep-learning'),'cnn') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='deep-learning'),'rnn') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='deep-learning'),'transformer') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='nlp'),'natural language processing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='nlp'),'text mining') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='nlp'),'spacy') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='computer-vision'),'computer vision') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='computer-vision'),'opencv') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='computer-vision'),'object detection') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='computer-vision'),'image classification') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='mlops'),'mlops') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='mlops'),'ml ops') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='mlops'),'model deployment') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='mlops'),'model serving') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='mlops'),'mlflow') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='feature-engineering'),'feature engineering') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='feature-engineering'),'feature selection') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='model-evaluation'),'model evaluation') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='model-evaluation'),'cross-validation') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='model-evaluation'),'cross validation') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='dl-frameworks'),'pytorch') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='dl-frameworks'),'tensorflow') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='dl-frameworks'),'keras') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='llms'),'large language models') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='llms'),'llm') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='llms'),'gpt') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='llms'),'openai') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='llms'),'langchain') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='prompt-engineering'),'prompt engineering') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='prompt-engineering'),'prompting') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='generative-ai'),'generative ai') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='generative-ai'),'gen ai') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='generative-ai'),'genai') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='generative-ai'),'stable diffusion') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='ui-design'),'ui design') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='ui-design'),'user interface') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='ui-design'),'ui/ux') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='ux-research'),'ux research') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='ux-research'),'user research') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='ux-research'),'user interviews') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='wireframing'),'wireframing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='wireframing'),'prototyping') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='wireframing'),'wireframes') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='figma'),'figma') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='figma'),'sketch') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='figma'),'adobe xd') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='design-systems'),'design system') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='design-systems'),'component library') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='interaction-design'),'interaction design') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='usability-testing'),'usability testing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='usability-testing'),'usability') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='information-architecture'),'information architecture') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='visual-design'),'visual design') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='visual-design'),'graphic design') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='visual-design'),'typography') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='user-journey-mapping'),'user journey') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='user-journey-mapping'),'journey mapping') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='user-journey-mapping'),'user flows') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='digital-marketing'),'digital marketing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='digital-marketing'),'online marketing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='content-marketing'),'content marketing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='content-marketing'),'content creation') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='content-marketing'),'content strategy') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='seo'),'seo') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='seo'),'search engine optimization') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='seo'),'sem') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='social-media-marketing'),'social media') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='social-media-marketing'),'social media marketing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='social-media-marketing'),'smm') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='email-marketing'),'email marketing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='email-marketing'),'mailchimp') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='email-marketing'),'email campaigns') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='copywriting'),'copywriting') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='copywriting'),'copy writing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='copywriting'),'ad copy') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='paid-advertising'),'paid ads') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='paid-advertising'),'google ads') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='paid-advertising'),'meta ads') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='paid-advertising'),'facebook ads') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='paid-advertising'),'ppc') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='marketing-analytics'),'marketing analytics') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='marketing-analytics'),'conversion tracking') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='google-analytics'),'google analytics') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='google-analytics'),'ga4') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='brand-strategy'),'brand strategy') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='brand-strategy'),'branding') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='crm-tools'),'crm') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='crm-tools'),'hubspot') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='crm-tools'),'salesforce') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='jupyter'),'jupyter') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='jupyter'),'jupyter notebook') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='jupyter'),'google colab') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='jupyter'),'colab') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='cloud-platforms'),'aws') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='cloud-platforms'),'gcp') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='cloud-platforms'),'azure') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='cloud-platforms'),'google cloud') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='cloud-platforms'),'amazon web services') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='cloud-platforms'),'cloud computing') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='docker'),'docker') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='docker'),'kubernetes') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='docker'),'k8s') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='docker'),'containers') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='docker'),'containerization') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='linux-cli'),'linux') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='linux-cli'),'command line') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='linux-cli'),'bash') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='linux-cli'),'shell scripting') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='linux-cli'),'unix') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='communication'),'communication skills') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='communication'),'written communication') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='communication'),'verbal communication') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='teamwork'),'teamwork') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='teamwork'),'collaboration') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='teamwork'),'cross-functional') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='problem-solving'),'problem solving') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='problem-solving'),'problem-solving') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='problem-solving'),'analytical skills') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='critical-thinking'),'critical thinking') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='leadership'),'leadership') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='leadership'),'team lead') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='project-management'),'project management') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='project-management'),'agile') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='project-management'),'scrum') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='project-management'),'jira') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='project-management'),'kanban') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='presentation-skills'),'presentation skills') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='presentation-skills'),'public speaking') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='time-management'),'time management') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='stakeholder-management'),'stakeholder management') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='stakeholder-management'),'stakeholders') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='adaptability'),'adaptability') on conflict do nothing;
insert into skill_aliases (skill_id,alias) values ((select id from skills where slug='adaptability'),'flexibility') on conflict do nothing;
insert into opportunities (slug,title,category,organization,description,url,is_remote,min_level,max_level,deadline,source) values ('dsn-ds-internship','DSN Data Science Internship','internship','Data Science Nigeria','Hands-on internship building data science solutions.','https://example.org/dsn-ds','true','200','500','2026-10-31','sample') on conflict do nothing;
insert into opportunities (slug,title,category,organization,description,url,is_remote,min_level,max_level,deadline,source) values ('ai-eng-fellowship','AI Engineering Fellowship','fellowship','AI Saturdays','Fellowship for building and deploying ML systems.','https://example.org/ai-fellow','true','300','700','2026-11-15','sample') on conflict do nothing;
insert into opportunities (slug,title,category,organization,description,url,is_remote,min_level,max_level,deadline,source) values ('futminna-frontend-hack','FUTMinna Frontend Hackathon','hackathon','DSN FUTMinna','48-hour hackathon to build web apps.','https://example.org/frontend-hack','false',null,null,'2026-10-20','sample') on conflict do nothing;
insert into opportunities (slug,title,category,organization,description,url,is_remote,min_level,max_level,deadline,source) values ('product-design-bootcamp','Product Design Bootcamp','training','DesignLab','Intensive product design training with a capstone.','https://example.org/design-bootcamp','true',null,null,'2026-11-05','sample') on conflict do nothing;
insert into opportunities (slug,title,category,organization,description,url,is_remote,min_level,max_level,deadline,source) values ('growth-marketing-internship','Growth Marketing Internship','internship','GrowthLab','Run real digital marketing campaigns end-to-end.','https://example.org/growth','true','200','500','2026-10-28','sample') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='dsn-ds-internship'),(select id from skills where slug='python'),'3') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='dsn-ds-internship'),(select id from skills where slug='statistics'),'2') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='dsn-ds-internship'),(select id from skills where slug='sql'),'2') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='dsn-ds-internship'),(select id from skills where slug='machine-learning'),'2') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='dsn-ds-internship'),(select id from skills where slug='data-visualization'),'1') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='ai-eng-fellowship'),(select id from skills where slug='python'),'3') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='ai-eng-fellowship'),(select id from skills where slug='deep-learning'),'3') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='ai-eng-fellowship'),(select id from skills where slug='dl-frameworks'),'3') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='ai-eng-fellowship'),(select id from skills where slug='mlops'),'2') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='ai-eng-fellowship'),(select id from skills where slug='nlp'),'2') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='futminna-frontend-hack'),(select id from skills where slug='javascript'),'3') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='futminna-frontend-hack'),(select id from skills where slug='react'),'3') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='futminna-frontend-hack'),(select id from skills where slug='html-css'),'2') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='futminna-frontend-hack'),(select id from skills where slug='git'),'2') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='product-design-bootcamp'),(select id from skills where slug='figma'),'3') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='product-design-bootcamp'),(select id from skills where slug='ui-design'),'3') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='product-design-bootcamp'),(select id from skills where slug='ux-research'),'2') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='product-design-bootcamp'),(select id from skills where slug='wireframing'),'2') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='growth-marketing-internship'),(select id from skills where slug='digital-marketing'),'3') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='growth-marketing-internship'),(select id from skills where slug='social-media-marketing'),'3') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='growth-marketing-internship'),(select id from skills where slug='seo'),'2') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='growth-marketing-internship'),(select id from skills where slug='content-marketing'),'2') on conflict do nothing;
insert into opportunity_skills (opportunity_id,skill_id,weight) values ((select id from opportunities where slug='growth-marketing-internship'),(select id from skills where slug='google-analytics'),'2') on conflict do nothing;
insert into opportunity_careers (opportunity_id,career_id) values ((select id from opportunities where slug='dsn-ds-internship'),(select id from careers where slug='data-scientist')) on conflict do nothing;
insert into opportunity_careers (opportunity_id,career_id) values ((select id from opportunities where slug='dsn-ds-internship'),(select id from careers where slug='ai-engineer')) on conflict do nothing;
insert into opportunity_careers (opportunity_id,career_id) values ((select id from opportunities where slug='ai-eng-fellowship'),(select id from careers where slug='ai-engineer')) on conflict do nothing;
insert into opportunity_careers (opportunity_id,career_id) values ((select id from opportunities where slug='futminna-frontend-hack'),(select id from careers where slug='software-developer')) on conflict do nothing;
insert into opportunity_careers (opportunity_id,career_id) values ((select id from opportunities where slug='product-design-bootcamp'),(select id from careers where slug='product-designer')) on conflict do nothing;
insert into opportunity_careers (opportunity_id,career_id) values ((select id from opportunities where slug='growth-marketing-internship'),(select id from careers where slug='digital-marketer')) on conflict do nothing;
