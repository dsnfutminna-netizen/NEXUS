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
