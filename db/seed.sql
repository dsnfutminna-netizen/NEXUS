-- =====================================================================
-- NEXUS — Seed Data (v1)
-- Run AFTER schema.sql.
--
-- Contents:
--   1. Proficiency levels (0..4)
--   2. Skill categories + skill taxonomy (~70 skills)
--   3. Industries + FUTMinna departments
--   4. The 5 v1 career pathways
--   5. THE ANSWER KEY: career -> required skill mappings (target level + weight)
--   6. Demo opportunities (clearly marked — safe to delete)
--
-- All mappings reference skills/careers by `slug`, so they survive re-seeding.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. PROFICIENCY LEVELS
-- ---------------------------------------------------------------------
insert into proficiency_levels (rank, code, label, description) values
  (0, 'none',         'None',         'No exposure yet'),
  (1, 'beginner',     'Beginner',     'Basic awareness; needs guidance'),
  (2, 'intermediate', 'Intermediate', 'Works independently on common tasks'),
  (3, 'advanced',     'Advanced',     'Handles complex work; can guide others'),
  (4, 'expert',       'Expert',       'Deep mastery; sets direction');

-- ---------------------------------------------------------------------
-- 2. SKILL CATEGORIES
-- ---------------------------------------------------------------------
insert into skill_categories (name, description) values
  ('Programming & Software Engineering', 'Languages, frameworks, engineering practice'),
  ('Data & Analytics',                   'Statistics, analysis, visualization'),
  ('Machine Learning & AI',              'ML, deep learning, modern AI'),
  ('Design & UX',                        'Product design, research, interaction'),
  ('Marketing & Growth',                 'Digital marketing, content, growth'),
  ('Tools & Platforms',                  'Environments, cloud, tooling'),
  ('Professional & Soft Skills',         'Communication, teamwork, leadership');

-- ---------------------------------------------------------------------
-- 2b. SKILLS  (name, slug, category)
-- ---------------------------------------------------------------------
insert into skills (name, slug, category_id)
select v.name, v.slug, c.id
from (values
  -- Programming & Software Engineering
  ('Python','python','Programming & Software Engineering'),
  ('JavaScript','javascript','Programming & Software Engineering'),
  ('TypeScript','typescript','Programming & Software Engineering'),
  ('Java','java','Programming & Software Engineering'),
  ('C++','cpp','Programming & Software Engineering'),
  ('SQL','sql','Programming & Software Engineering'),
  ('HTML & CSS','html-css','Programming & Software Engineering'),
  ('React','react','Programming & Software Engineering'),
  ('Node.js','nodejs','Programming & Software Engineering'),
  ('Git & Version Control','git','Programming & Software Engineering'),
  ('REST APIs','rest-apis','Programming & Software Engineering'),
  ('Relational Databases','relational-databases','Programming & Software Engineering'),
  ('Software Testing','software-testing','Programming & Software Engineering'),
  ('System Design','system-design','Programming & Software Engineering'),
  ('Object-Oriented Programming','oop','Programming & Software Engineering'),
  ('Data Structures & Algorithms','dsa','Programming & Software Engineering'),
  ('Mobile Development','mobile-development','Programming & Software Engineering'),
  -- Data & Analytics
  ('Statistics','statistics','Data & Analytics'),
  ('Data Analysis','data-analysis','Data & Analytics'),
  ('Data Visualization','data-visualization','Data & Analytics'),
  ('Spreadsheets (Excel/Sheets)','spreadsheets','Data & Analytics'),
  ('Data Cleaning & Wrangling','data-cleaning','Data & Analytics'),
  ('Exploratory Data Analysis','eda','Data & Analytics'),
  ('Business Intelligence (Power BI/Tableau)','business-intelligence','Data & Analytics'),
  ('Data Storytelling','data-storytelling','Data & Analytics'),
  ('A/B Testing & Experimentation','ab-testing','Data & Analytics'),
  -- Machine Learning & AI
  ('Machine Learning','machine-learning','Machine Learning & AI'),
  ('Deep Learning','deep-learning','Machine Learning & AI'),
  ('Natural Language Processing','nlp','Machine Learning & AI'),
  ('Computer Vision','computer-vision','Machine Learning & AI'),
  ('Model Deployment & MLOps','mlops','Machine Learning & AI'),
  ('Feature Engineering','feature-engineering','Machine Learning & AI'),
  ('Model Evaluation','model-evaluation','Machine Learning & AI'),
  ('PyTorch / TensorFlow','dl-frameworks','Machine Learning & AI'),
  ('Large Language Models','llms','Machine Learning & AI'),
  ('Prompt Engineering','prompt-engineering','Machine Learning & AI'),
  ('Generative AI','generative-ai','Machine Learning & AI'),
  -- Design & UX
  ('UI Design','ui-design','Design & UX'),
  ('UX Research','ux-research','Design & UX'),
  ('Wireframing & Prototyping','wireframing','Design & UX'),
  ('Figma','figma','Design & UX'),
  ('Design Systems','design-systems','Design & UX'),
  ('Interaction Design','interaction-design','Design & UX'),
  ('Usability Testing','usability-testing','Design & UX'),
  ('Information Architecture','information-architecture','Design & UX'),
  ('Visual & Graphic Design','visual-design','Design & UX'),
  ('User Journey Mapping','user-journey-mapping','Design & UX'),
  -- Marketing & Growth
  ('Digital Marketing','digital-marketing','Marketing & Growth'),
  ('Content Marketing','content-marketing','Marketing & Growth'),
  ('SEO','seo','Marketing & Growth'),
  ('Social Media Marketing','social-media-marketing','Marketing & Growth'),
  ('Email Marketing','email-marketing','Marketing & Growth'),
  ('Copywriting','copywriting','Marketing & Growth'),
  ('Paid Advertising (Google/Meta Ads)','paid-advertising','Marketing & Growth'),
  ('Marketing Analytics','marketing-analytics','Marketing & Growth'),
  ('Google Analytics','google-analytics','Marketing & Growth'),
  ('Brand Strategy','brand-strategy','Marketing & Growth'),
  ('CRM Tools','crm-tools','Marketing & Growth'),
  -- Tools & Platforms
  ('Jupyter Notebooks','jupyter','Tools & Platforms'),
  ('Cloud Platforms (AWS/GCP/Azure)','cloud-platforms','Tools & Platforms'),
  ('Docker','docker','Tools & Platforms'),
  ('Linux & Command Line','linux-cli','Tools & Platforms'),
  -- Professional & Soft Skills
  ('Communication','communication','Professional & Soft Skills'),
  ('Teamwork & Collaboration','teamwork','Professional & Soft Skills'),
  ('Problem Solving','problem-solving','Professional & Soft Skills'),
  ('Critical Thinking','critical-thinking','Professional & Soft Skills'),
  ('Leadership','leadership','Professional & Soft Skills'),
  ('Project Management','project-management','Professional & Soft Skills'),
  ('Presentation Skills','presentation-skills','Professional & Soft Skills'),
  ('Time Management','time-management','Professional & Soft Skills'),
  ('Stakeholder Management','stakeholder-management','Professional & Soft Skills'),
  ('Adaptability','adaptability','Professional & Soft Skills')
) as v(name, slug, category)
join skill_categories c on c.name = v.category;

-- ---------------------------------------------------------------------
-- 3. INDUSTRIES + DEPARTMENTS
-- ---------------------------------------------------------------------
insert into industries (name) values
  ('Technology & Software'), ('Finance & Fintech'), ('Healthcare & HealthTech'),
  ('Education & EdTech'), ('E-commerce & Retail'), ('Telecommunications'),
  ('Agriculture & AgriTech'), ('Energy & Power'), ('Government & Public Sector'),
  ('Media & Entertainment'), ('Consulting'), ('Manufacturing'),
  ('Nonprofit & NGO'), ('Research & Academia');

insert into departments (name, faculty) values
  ('Computer Science','SICT'),
  ('Cyber Security Science','SICT'),
  ('Information Technology','SICT'),
  ('Information & Media Technology','SICT'),
  ('Library & Information Technology','SICT'),
  ('Statistics','SPS'),
  ('Mathematics','SPS'),
  ('Physics','SPS'),
  ('Computer Engineering','SEET'),
  ('Electrical & Electronics Engineering','SEET'),
  ('Telecommunications Engineering','SEET'),
  ('Mechatronics Engineering','SEET'),
  ('Mechanical Engineering','SEET'),
  ('Civil Engineering','SEET'),
  ('Chemical Engineering','SEET'),
  ('Agricultural & Bioresources Engineering','SEET'),
  ('Agricultural Economics & Extension Technology','SAAT'),
  ('Animal Production','SAAT'),
  ('Crop Production','SAAT'),
  ('Soil Science & Land Management','SAAT'),
  ('Water Resources, Aquaculture & Fisheries Technology','SAAT'),
  ('Biochemistry','SLS'),
  ('Microbiology','SLS'),
  ('Plant Biology','SLS'),
  ('Geology','SPS'),
  ('Architecture','SET'),
  ('Building Technology','SET'),
  ('Quantity Surveying','SET'),
  ('Urban & Regional Planning','SET'),
  ('Estate Management & Valuation','SET'),
  ('Industrial & Technology Education','SSTE'),
  ('Other','—');

-- ---------------------------------------------------------------------
-- 4. CAREER PATHWAYS
-- ---------------------------------------------------------------------
insert into careers (name, slug, description) values
  ('Data Scientist','data-scientist',
     'Turns data into insight and predictive models using statistics, Python and ML.'),
  ('AI Engineer','ai-engineer',
     'Builds, deploys and scales machine-learning and AI systems in production.'),
  ('Software Developer','software-developer',
     'Designs and builds reliable software applications and services.'),
  ('Product Designer','product-designer',
     'Researches users and designs usable, valuable product experiences.'),
  ('Digital Marketer','digital-marketer',
     'Grows audiences and conversions across digital channels using data.'),
  ('Cybersecurity Analyst','cybersecurity-analyst',
     'Monitors, detects, and defends networks and applications against cyber threats.'),
  ('Cloud / DevOps Engineer','devops-engineer',
     'Automates cloud infrastructure, CI/CD pipelines, and system reliability.'),
  ('Data Engineer','data-engineer',
     'Architects and maintains data pipelines, data warehouses, and ETL infrastructure.'),
  ('Product Manager','product-manager',
     'Defines product vision, prioritizes features, and aligns cross-functional engineering and design teams.'),
  ('UI/UX Researcher','ux-researcher',
     'Conducts user research, usability testing, and translates user behavior into actionable design insights.'),
  ('Embedded Systems & Robotics Engineer','embedded-robotics',
     'Designs microcontrollers, hardware interfaces, IoT devices, and robotic control systems.');

-- ---------------------------------------------------------------------
-- 5. CAREER -> REQUIRED SKILLS  (target_rank 1..3, weight 3=core/2=important/1=nice)
-- ---------------------------------------------------------------------
insert into career_required_skills (career_id, skill_id, target_rank, weight)
select c.id, s.id, v.target_rank, v.weight
from (values
  -- DATA SCIENTIST
  ('data-scientist','python',3,3),
  ('data-scientist','statistics',3,3),
  ('data-scientist','machine-learning',3,3),
  ('data-scientist','data-analysis',3,3),
  ('data-scientist','sql',2,3),
  ('data-scientist','data-cleaning',3,2),
  ('data-scientist','data-visualization',2,2),
  ('data-scientist','eda',2,2),
  ('data-scientist','feature-engineering',2,2),
  ('data-scientist','model-evaluation',2,2),
  ('data-scientist','data-storytelling',2,2),
  ('data-scientist','communication',2,2),
  ('data-scientist','jupyter',2,1),
  ('data-scientist','git',2,1),
  ('data-scientist','deep-learning',1,1),

  -- AI ENGINEER
  ('ai-engineer','python',3,3),
  ('ai-engineer','machine-learning',3,3),
  ('ai-engineer','deep-learning',3,3),
  ('ai-engineer','dl-frameworks',3,3),
  ('ai-engineer','mlops',2,3),
  ('ai-engineer','nlp',2,2),
  ('ai-engineer','llms',2,2),
  ('ai-engineer','dsa',2,2),
  ('ai-engineer','rest-apis',2,2),
  ('ai-engineer','docker',2,2),
  ('ai-engineer','cloud-platforms',2,2),
  ('ai-engineer','model-evaluation',2,2),
  ('ai-engineer','git',2,2),
  ('ai-engineer','communication',2,2),
  ('ai-engineer','generative-ai',2,1),
  ('ai-engineer','prompt-engineering',2,1),
  ('ai-engineer','sql',1,1),

  -- SOFTWARE DEVELOPER
  ('software-developer','dsa',3,3),
  ('software-developer','oop',3,3),
  ('software-developer','git',3,3),
  ('software-developer','javascript',3,3),
  ('software-developer','problem-solving',3,3),
  ('software-developer','rest-apis',2,3),
  ('software-developer','relational-databases',2,2),
  ('software-developer','sql',2,2),
  ('software-developer','software-testing',2,2),
  ('software-developer','system-design',2,2),
  ('software-developer','react',2,2),
  ('software-developer','nodejs',2,2),
  ('software-developer','html-css',2,2),
  ('software-developer','communication',2,2),
  ('software-developer','teamwork',2,2),
  ('software-developer','docker',1,1),
  ('software-developer','cloud-platforms',1,1),

  -- PRODUCT DESIGNER
  ('product-designer','ui-design',3,3),
  ('product-designer','ux-research',3,3),
  ('product-designer','figma',3,3),
  ('product-designer','wireframing',3,3),
  ('product-designer','communication',3,3),
  ('product-designer','design-systems',2,2),
  ('product-designer','interaction-design',2,2),
  ('product-designer','usability-testing',2,2),
  ('product-designer','user-journey-mapping',2,2),
  ('product-designer','information-architecture',2,2),
  ('product-designer','visual-design',2,2),
  ('product-designer','presentation-skills',2,2),
  ('product-designer','stakeholder-management',2,2),
  ('product-designer','problem-solving',2,2),

  -- DIGITAL MARKETER
  ('digital-marketer','digital-marketing',3,3),
  ('digital-marketer','content-marketing',3,3),
  ('digital-marketer','social-media-marketing',3,3),
  ('digital-marketer','communication',3,3),
  ('digital-marketer','seo',2,3),
  ('digital-marketer','copywriting',2,2),
  ('digital-marketer','email-marketing',2,2),
  ('digital-marketer','paid-advertising',2,2),
  ('digital-marketer','marketing-analytics',2,2),
  ('digital-marketer','google-analytics',2,2),
  ('digital-marketer','brand-strategy',2,2),
  ('digital-marketer','presentation-skills',2,2),
  ('digital-marketer','crm-tools',2,1),
  ('digital-marketer','data-analysis',1,1)
) as v(career_slug, skill_slug, target_rank, weight)
join careers c on c.slug = v.career_slug
join skills  s on s.slug = v.skill_slug;

-- =====================================================================
-- 6. DEMO OPPORTUNITIES  (safe to delete — for testing the match views)
-- =====================================================================
insert into opportunities (title, slug, category, organization, description, url, is_remote, min_level, max_level, deadline, source) values
  ('DSN Data Science Internship','dsn-ds-internship','internship','Data Science Nigeria',
     'Hands-on internship building data science solutions.','https://example.org/dsn-ds', true, 200,500,'2026-10-31','seed'),
  ('AI Engineering Fellowship','ai-eng-fellowship','fellowship','AI Saturdays',
     'Fellowship for building and deploying ML systems.','https://example.org/ai-fellow', true, 300,700,'2026-11-15','seed'),
  ('FUTMinna Frontend Hackathon','futminna-frontend-hack','hackathon','DSN FUTMinna',
     '48-hour hackathon to build web apps.','https://example.org/frontend-hack', false, null,null,'2026-10-20','seed'),
  ('Product Design Bootcamp','product-design-bootcamp','training','DesignLab',
     'Intensive product design training with a capstone.','https://example.org/design-bootcamp', true, null,null,'2026-11-05','seed'),
  ('Growth Marketing Internship','growth-marketing-internship','internship','GrowthLab',
     'Run real digital marketing campaigns end-to-end.','https://example.org/growth', true, 200,500,'2026-10-28','seed');

insert into opportunity_skills (opportunity_id, skill_id, weight)
select o.id, s.id, v.weight
from (values
  ('dsn-ds-internship','python',3),
  ('dsn-ds-internship','statistics',2),
  ('dsn-ds-internship','sql',2),
  ('dsn-ds-internship','machine-learning',2),
  ('dsn-ds-internship','data-visualization',1),
  ('ai-eng-fellowship','python',3),
  ('ai-eng-fellowship','deep-learning',3),
  ('ai-eng-fellowship','dl-frameworks',3),
  ('ai-eng-fellowship','mlops',2),
  ('ai-eng-fellowship','nlp',2),
  ('futminna-frontend-hack','javascript',3),
  ('futminna-frontend-hack','react',3),
  ('futminna-frontend-hack','html-css',2),
  ('futminna-frontend-hack','git',2),
  ('product-design-bootcamp','figma',3),
  ('product-design-bootcamp','ui-design',3),
  ('product-design-bootcamp','ux-research',2),
  ('product-design-bootcamp','wireframing',2),
  ('growth-marketing-internship','digital-marketing',3),
  ('growth-marketing-internship','social-media-marketing',3),
  ('growth-marketing-internship','seo',2),
  ('growth-marketing-internship','content-marketing',2),
  ('growth-marketing-internship','google-analytics',2)
) as v(opp_slug, skill_slug, weight)
join opportunities o on o.slug = v.opp_slug
join skills s        on s.slug = v.skill_slug;

insert into opportunity_careers (opportunity_id, career_id)
select o.id, c.id
from (values
  ('dsn-ds-internship','data-scientist'),
  ('dsn-ds-internship','ai-engineer'),
  ('ai-eng-fellowship','ai-engineer'),
  ('futminna-frontend-hack','software-developer'),
  ('product-design-bootcamp','product-designer'),
  ('growth-marketing-internship','digital-marketer')
) as v(opp_slug, career_slug)
join opportunities o on o.slug = v.opp_slug
join careers c       on c.slug = v.career_slug;

-- =====================================================================
-- Done. Verify with:
--   select name, (select count(*) from career_required_skills where career_id=careers.id) skills
--   from careers order by name;
-- =====================================================================
