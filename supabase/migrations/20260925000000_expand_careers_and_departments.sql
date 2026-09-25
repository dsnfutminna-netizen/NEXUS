-- Additive migration: Expand careers, skills, and FUTMinna departments

-- 1. EXPAND FUTMINNA DEPARTMENTS
insert into public.departments (name, faculty) values
  ('Agricultural & Bioresources Engineering', 'SEET'),
  ('Agricultural Economics & Extension Technology', 'SAAT'),
  ('Animal Production', 'SAAT'),
  ('Crop Production', 'SAAT'),
  ('Soil Science & Land Management', 'SAAT'),
  ('Water Resources, Aquaculture & Fisheries Technology', 'SAAT'),
  ('Biochemistry', 'SLS'),
  ('Microbiology', 'SLS'),
  ('Plant Biology', 'SLS'),
  ('Geology', 'SPS'),
  ('Architecture', 'SET'),
  ('Building Technology', 'SET'),
  ('Quantity Surveying', 'SET'),
  ('Urban & Regional Planning', 'SET'),
  ('Estate Management & Valuation', 'SET'),
  ('Industrial & Technology Education', 'SSTE')
on conflict (name) do nothing;

-- 2. EXPAND CAREER PATHWAYS
insert into public.careers (name, slug, description) values
  ('Cybersecurity Analyst', 'cybersecurity-analyst', 'Monitors, detects, and defends networks and applications against cyber threats.'),
  ('Cloud / DevOps Engineer', 'devops-engineer', 'Automates cloud infrastructure, CI/CD pipelines, and system reliability.'),
  ('Data Engineer', 'data-engineer', 'Architects and maintains data pipelines, data warehouses, and ETL infrastructure.'),
  ('Product Manager', 'product-manager', 'Defines product vision, prioritizes features, and aligns cross-functional engineering and design teams.'),
  ('UI/UX Researcher', 'ux-researcher', 'Conducts user research, usability testing, and translates user behavior into actionable design insights.'),
  ('Embedded Systems & Robotics Engineer', 'embedded-robotics', 'Designs microcontrollers, hardware interfaces, IoT devices, and robotic control systems.')
on conflict (slug) do nothing;

-- 3. MAP REQUIRED SKILLS FOR NEW CAREERS
insert into public.career_required_skills (career_id, skill_id, target_rank, weight)
select c.id, s.id, v.target_rank, v.weight
from (values
  -- Cybersecurity Analyst
  ('cybersecurity-analyst', 'linux-cli', 3, 3),
  ('cybersecurity-analyst', 'python', 2, 2),
  ('cybersecurity-analyst', 'problem-solving', 3, 3),
  ('cybersecurity-analyst', 'critical-thinking', 3, 3),
  ('cybersecurity-analyst', 'communication', 2, 2),

  -- Cloud / DevOps Engineer
  ('devops-engineer', 'docker', 3, 3),
  ('devops-engineer', 'cloud-platforms', 3, 3),
  ('devops-engineer', 'linux-cli', 3, 3),
  ('devops-engineer', 'git', 3, 3),
  ('devops-engineer', 'python', 2, 2),

  -- Data Engineer
  ('data-engineer', 'python', 3, 3),
  ('data-engineer', 'sql', 3, 3),
  ('data-engineer', 'relational-databases', 3, 3),
  ('data-engineer', 'data-cleaning', 3, 3),
  ('data-engineer', 'cloud-platforms', 2, 2),

  -- Product Manager
  ('product-manager', 'project-management', 3, 3),
  ('product-manager', 'communication', 3, 3),
  ('product-manager', 'stakeholder-management', 3, 3),
  ('product-manager', 'problem-solving', 3, 3),
  ('product-manager', 'data-analysis', 2, 2),
  ('product-manager', 'ux-research', 2, 2),

  -- UI/UX Researcher
  ('ux-researcher', 'ux-research', 3, 3),
  ('ux-researcher', 'usability-testing', 3, 3),
  ('ux-researcher', 'user-journey-mapping', 3, 3),
  ('ux-researcher', 'figma', 2, 2),
  ('ux-researcher', 'communication', 3, 3),

  -- Embedded Systems & Robotics Engineer
  ('embedded-robotics', 'cpp', 3, 3),
  ('embedded-robotics', 'python', 2, 2),
  ('embedded-robotics', 'linux-cli', 2, 2),
  ('embedded-robotics', 'problem-solving', 3, 3)
) as v(career_slug, skill_slug, target_rank, weight)
join public.careers c on c.slug = v.career_slug
join public.skills s on s.slug = v.skill_slug
on conflict (career_id, skill_id) do nothing;
