-- Official programs reviewed on 20 October 2026. Review availability monthly.
-- These are learning/leadership paths, not open job applications.
insert into public.opportunities
  (slug, title, category, organization, description, url, is_remote, source, external_id, fetched_at)
values
  ('microsoft-student-ambassadors', 'Microsoft Learn Student Ambassadors', 'leadership', 'Microsoft',
   'University students can register to build technology and community leadership skills. Microsoft lists registration activities and says no application is required; check current eligibility before joining.',
   'https://learn.microsoft.com/en-us/training/student-hub/become-a-student-ambassador', true, 'curated', 'microsoft-student-ambassadors', now()),
  ('forage-job-simulations', 'Forage virtual job simulations', 'training', 'Forage',
   'Explore free, self-paced simulations built with employers to try real-world tasks and compare your work with examples. A simulation is a learning experience, not a job offer.',
   'https://www.theforage.com/', true, 'curated', 'forage-job-simulations', now()),
  ('ibm-skillsbuild-university', 'IBM SkillsBuild for university students', 'training', 'IBM',
   'Free, flexible courses and applied projects for university students, with shareable credentials on eligible learning paths. Check the current catalog and account requirements.',
   'https://skillsbuild.org/university/students', true, 'curated', 'ibm-skillsbuild-university', now()),
  ('cisco-networking-academy', 'Cisco Networking Academy free courses', 'training', 'Cisco',
   'Free online courses across networking, cybersecurity, programming, AI and data science. Choose a self-paced course from the official catalog to start learning.',
   'https://www.netacad.com/', true, 'curated', 'cisco-networking-academy', now()),
  ('kaggle-learn-courses', 'Kaggle Learn courses', 'training', 'Kaggle',
   'Free, short courses in Python, data analysis and machine learning to build practical data skills. Browse the current course catalog and prerequisites.',
   'https://www.kaggle.com/learn/', true, 'curated', 'kaggle-learn-courses', now())
on conflict (slug) do nothing;

insert into public.opportunity_skills (opportunity_id, skill_id, weight)
select o.id, s.id, 3
from public.opportunities o cross join public.skills s
where (o.slug='microsoft-student-ambassadors' and s.slug in ('leadership','communication','cloud-platforms'))
   or (o.slug='forage-job-simulations' and s.slug in ('communication','project-management'))
   or (o.slug='ibm-skillsbuild-university' and s.slug in ('data-analysis','machine-learning'))
   or (o.slug='cisco-networking-academy' and s.slug in ('python','data-analysis'))
   or (o.slug='kaggle-learn-courses' and s.slug in ('python','data-analysis','machine-learning'))
on conflict do nothing;
