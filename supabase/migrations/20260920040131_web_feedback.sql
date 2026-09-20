-- Additive web migration. Apply to the isolated test project first.
-- The helper reads only the caller's RLS-protected profile; never trusts user_metadata.
create or replace function public.is_pilot_admin() returns boolean
language sql stable security invoker set search_path=public
as $$ select exists(select 1 from public.profiles where id=(select auth.uid()) and role='admin') $$;
revoke all on function public.is_pilot_admin() from public,anon;
grant execute on function public.is_pilot_admin() to authenticated;
create table public.feedback_requests (
 id uuid primary key default gen_random_uuid(),
 student_id uuid not null references public.profiles(id) on delete cascade,
 category text not null check(category in ('problem','idea','experience','account')),
 body text not null check(char_length(body) between 10 and 4000),
 usefulness smallint check(usefulness between 1 and 5),
 allow_contact boolean not null default false,
 contact_email text,
 page_path text not null default '' check(char_length(page_path)<=150),
 app_version text not null default 'web-0.1',
 status text not null default 'new' check(status in ('new','reviewing','resolved')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check(allow_contact or contact_email is null)
);
create index feedback_requests_student on public.feedback_requests(student_id);
create index feedback_requests_status_created on public.feedback_requests(status,created_at desc);
alter table public.feedback_requests enable row level security;
revoke all on public.feedback_requests from anon,authenticated;
grant select on public.feedback_requests to authenticated;
grant insert(id,student_id,category,body,usefulness,allow_contact,contact_email,page_path,app_version) on public.feedback_requests to authenticated;
grant update(status) on public.feedback_requests to authenticated;
create policy feedback_owner_read on public.feedback_requests for select to authenticated using(student_id=(select auth.uid()) or (select public.is_pilot_admin()));
create policy feedback_owner_insert on public.feedback_requests for insert to authenticated with check(student_id=(select auth.uid()) and status='new' and (contact_email is null or contact_email=(select auth.jwt()->>'email')));
create policy feedback_admin_update on public.feedback_requests for update to authenticated using((select public.is_pilot_admin())) with check((select public.is_pilot_admin()));
create trigger feedback_updated before update on public.feedback_requests for each row execute function public.set_updated_at();
create table public.feedback_notes (
 id uuid primary key default gen_random_uuid(),
 feedback_id uuid not null references public.feedback_requests(id) on delete cascade,
 author_id uuid references public.profiles(id) on delete set null,
 body text not null check(char_length(body) between 1 and 4000),
 created_at timestamptz not null default now()
);
create index feedback_notes_report on public.feedback_notes(feedback_id);
create index feedback_notes_author on public.feedback_notes(author_id);
alter table public.feedback_notes enable row level security;
revoke all on public.feedback_notes from anon,authenticated;
grant select on public.feedback_notes to authenticated;
grant insert(feedback_id,author_id,body) on public.feedback_notes to authenticated;
create policy notes_admin_read on public.feedback_notes for select to authenticated using((select public.is_pilot_admin()));
create policy notes_admin_insert on public.feedback_notes for insert to authenticated with check((select public.is_pilot_admin()) and author_id=(select auth.uid()));
