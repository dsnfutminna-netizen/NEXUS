-- Official, evergreen student programs verified on 19 October 2026.
-- Review these links and eligibility monthly; remove them if providers close.
insert into public.opportunities
  (slug, title, category, organization, description, url, is_remote, source, external_id, fetched_at)
values
  ('github-student-developer-pack', 'GitHub Student Developer Pack', 'training', 'GitHub Education',
   'Verified students can apply for professional developer tools and learning resources. GitHub checks current enrollment; review its eligibility and partner terms before applying.',
   'https://github.com/education/students', true, 'curated', 'github-student-developer-pack', now()),
  ('aws-educate-cloud-learning', 'AWS Educate cloud learning', 'training', 'Amazon Web Services',
   'Free, self-paced cloud and AI learning paths with hands-on practice. AWS Educate is open to learners across many countries; check current local age and account requirements on the official page.',
   'https://aws.amazon.com/education/awseducate/', true, 'curated', 'aws-educate-cloud-learning', now())
on conflict (slug) do nothing;

insert into public.opportunity_skills (opportunity_id, skill_id, weight)
select o.id, s.id, 3 from public.opportunities o cross join public.skills s
where (o.slug='github-student-developer-pack' and s.slug='git')
   or (o.slug='aws-educate-cloud-learning' and s.slug='cloud-platforms')
on conflict do nothing;
