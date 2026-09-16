# NEXUS Career Pathways — v1 Reference ("the answer key")

This is the human-readable version of the data in `db/seed.sql`. The **Data &
Research teams own this file** — review it, correct it, and expand it. Every
change here should be mirrored in `seed.sql` (or generated from it later).

> Why this matters: the skill-gap engine and opportunity matcher are only as
> good as these target levels. This *is* the intelligence — curated by humans,
> executed by SQL.

## Proficiency scale (0–4)
| Rank | Label | Meaning |
|---|---|---|
| 0 | None | No exposure yet |
| 1 | Beginner | Basic awareness; needs guidance |
| 2 | Intermediate | Works independently on common tasks |
| 3 | Advanced | Handles complex work; can guide others |
| 4 | Expert | Deep mastery; sets direction |

**Importance weight:** `3 = core` · `2 = important` · `1 = nice-to-have`.
Gap analysis prioritises fixes by `gap × importance`.

---

## 1. Data Scientist
> Turns data into insight and predictive models using statistics, Python and ML.

| Skill | Target | Importance |
|---|:--:|:--:|
| Python | Advanced | core |
| Statistics | Advanced | core |
| Machine Learning | Advanced | core |
| Data Analysis | Advanced | core |
| SQL | Intermediate | core |
| Data Cleaning & Wrangling | Advanced | important |
| Data Visualization | Intermediate | important |
| Exploratory Data Analysis | Intermediate | important |
| Feature Engineering | Intermediate | important |
| Model Evaluation | Intermediate | important |
| Data Storytelling | Intermediate | important |
| Communication | Intermediate | important |
| Jupyter Notebooks | Intermediate | nice-to-have |
| Git & Version Control | Intermediate | nice-to-have |
| Deep Learning | Beginner | nice-to-have |

## 2. AI Engineer
> Builds, deploys and scales machine-learning and AI systems in production.

| Skill | Target | Importance |
|---|:--:|:--:|
| Python | Advanced | core |
| Machine Learning | Advanced | core |
| Deep Learning | Advanced | core |
| PyTorch / TensorFlow | Advanced | core |
| Model Deployment & MLOps | Intermediate | core |
| Natural Language Processing | Intermediate | important |
| Large Language Models | Intermediate | important |
| Data Structures & Algorithms | Intermediate | important |
| REST APIs | Intermediate | important |
| Docker | Intermediate | important |
| Cloud Platforms | Intermediate | important |
| Model Evaluation | Intermediate | important |
| Git & Version Control | Intermediate | important |
| Communication | Intermediate | important |
| Generative AI | Intermediate | nice-to-have |
| Prompt Engineering | Intermediate | nice-to-have |
| SQL | Beginner | nice-to-have |

## 3. Software Developer
> Designs and builds reliable software applications and services.

| Skill | Target | Importance |
|---|:--:|:--:|
| Data Structures & Algorithms | Advanced | core |
| Object-Oriented Programming | Advanced | core |
| Git & Version Control | Advanced | core |
| JavaScript | Advanced | core |
| Problem Solving | Advanced | core |
| REST APIs | Intermediate | core |
| Relational Databases | Intermediate | important |
| SQL | Intermediate | important |
| Software Testing | Intermediate | important |
| System Design | Intermediate | important |
| React | Intermediate | important |
| Node.js | Intermediate | important |
| HTML & CSS | Intermediate | important |
| Communication | Intermediate | important |
| Teamwork & Collaboration | Intermediate | important |
| Docker | Beginner | nice-to-have |
| Cloud Platforms | Beginner | nice-to-have |

## 4. Product Designer
> Researches users and designs usable, valuable product experiences.

| Skill | Target | Importance |
|---|:--:|:--:|
| UI Design | Advanced | core |
| UX Research | Advanced | core |
| Figma | Advanced | core |
| Wireframing & Prototyping | Advanced | core |
| Communication | Advanced | core |
| Design Systems | Intermediate | important |
| Interaction Design | Intermediate | important |
| Usability Testing | Intermediate | important |
| User Journey Mapping | Intermediate | important |
| Information Architecture | Intermediate | important |
| Visual & Graphic Design | Intermediate | important |
| Presentation Skills | Intermediate | important |
| Stakeholder Management | Intermediate | important |
| Problem Solving | Intermediate | important |

## 5. Digital Marketer
> Grows audiences and conversions across digital channels using data.

| Skill | Target | Importance |
|---|:--:|:--:|
| Digital Marketing | Advanced | core |
| Content Marketing | Advanced | core |
| Social Media Marketing | Advanced | core |
| Communication | Advanced | core |
| SEO | Intermediate | core |
| Copywriting | Intermediate | important |
| Email Marketing | Intermediate | important |
| Paid Advertising (Google/Meta Ads) | Intermediate | important |
| Marketing Analytics | Intermediate | important |
| Google Analytics | Intermediate | important |
| Brand Strategy | Intermediate | important |
| Presentation Skills | Intermediate | important |
| CRM Tools | Intermediate | nice-to-have |
| Data Analysis | Beginner | nice-to-have |

---

### How to change a pathway
1. Edit the table here (proposal + review by Data/Research team).
2. Update the matching rows in `db/seed.sql` (`career_required_skills`).
3. Re-run `seed.sql` on a fresh DB, or write an `UPDATE` migration.

### Open questions for the cohort
- Are these target levels realistic for a FUTMinna undergraduate?
- Should we validate them against real Nigerian job postings / DSN mentors?
- Which 6th career (if any) do students most want next?
