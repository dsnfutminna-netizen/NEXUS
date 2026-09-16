-- =====================================================================
-- NEXUS — SQLite schema for the PILOT app (app/nexus.db)
-- Mirrors db/schema.sql (Postgres/Supabase = production target).
-- Differences: SQLite types, no enums (CHECK instead), no RLS/views
-- (intelligence is computed in app/intelligence.py). Enable FKs per-conn.
-- =====================================================================

CREATE TABLE IF NOT EXISTS proficiency_levels (
  rank        INTEGER PRIMARY KEY,
  code        TEXT UNIQUE NOT NULL,
  label       TEXT NOT NULL,
  description TEXT
);

CREATE TABLE IF NOT EXISTS skill_categories (
  id   INTEGER PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  description TEXT
);

CREATE TABLE IF NOT EXISTS skills (
  id          INTEGER PRIMARY KEY,
  name        TEXT UNIQUE NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  category_id INTEGER NOT NULL REFERENCES skill_categories(id),
  is_active   INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS careers (
  id          INTEGER PRIMARY KEY,
  name        TEXT UNIQUE NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  description TEXT,
  is_active   INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS career_required_skills (
  career_id   INTEGER NOT NULL REFERENCES careers(id) ON DELETE CASCADE,
  skill_id    INTEGER NOT NULL REFERENCES skills(id)  ON DELETE CASCADE,
  target_rank INTEGER NOT NULL REFERENCES proficiency_levels(rank),
  weight      INTEGER NOT NULL DEFAULT 2 CHECK (weight BETWEEN 1 AND 3),
  PRIMARY KEY (career_id, skill_id)
);

CREATE TABLE IF NOT EXISTS industries (
  id   INTEGER PRIMARY KEY,
  name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS departments (
  id      INTEGER PRIMARY KEY,
  name    TEXT UNIQUE NOT NULL,
  faculty TEXT
);

CREATE TABLE IF NOT EXISTS profiles (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  full_name        TEXT NOT NULL,
  email            TEXT UNIQUE NOT NULL,
  password_salt    TEXT NOT NULL,
  password_hash    TEXT NOT NULL,
  role             TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student','contributor','admin')),
  department_id    INTEGER REFERENCES departments(id),
  level            INTEGER CHECK (level IN (100,200,300,400,500,600,700)),
  cgpa             REAL    CHECK (cgpa >= 0 AND cgpa <= 5.0),
  target_career_id INTEGER REFERENCES careers(id),
  bio              TEXT,
  data_consent     INTEGER NOT NULL DEFAULT 0,
  created_at       TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS student_skills (
  student_id       INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  skill_id         INTEGER NOT NULL REFERENCES skills(id)   ON DELETE CASCADE,
  proficiency_rank INTEGER NOT NULL REFERENCES proficiency_levels(rank),
  updated_at       TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (student_id, skill_id)
);

CREATE TABLE IF NOT EXISTS student_interests (
  student_id  INTEGER NOT NULL REFERENCES profiles(id)   ON DELETE CASCADE,
  industry_id INTEGER NOT NULL REFERENCES industries(id) ON DELETE CASCADE,
  PRIMARY KEY (student_id, industry_id)
);

CREATE TABLE IF NOT EXISTS opportunities (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  slug         TEXT UNIQUE,
  title        TEXT NOT NULL,
  category     TEXT NOT NULL,
  organization TEXT,
  description  TEXT,
  url          TEXT,
  is_remote    INTEGER NOT NULL DEFAULT 0,
  min_level    INTEGER,
  max_level    INTEGER,
  deadline     TEXT,
  is_active    INTEGER NOT NULL DEFAULT 1,
  source       TEXT,
  external_id  TEXT,            -- id from the source platform (dedupe key)
  location     TEXT,
  posted_at    TEXT,            -- when the source posted it
  fetched_at   TEXT,            -- when we last ingested it
  tags         TEXT,            -- comma-separated raw tags from the source
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
-- dedupe external postings on (source, external_id); curated rows (external_id NULL) are exempt
CREATE UNIQUE INDEX IF NOT EXISTS ux_opps_source_external
  ON opportunities(source, external_id) WHERE external_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS opportunity_skills (
  opportunity_id INTEGER NOT NULL REFERENCES opportunities(id) ON DELETE CASCADE,
  skill_id       INTEGER NOT NULL REFERENCES skills(id)        ON DELETE CASCADE,
  weight         INTEGER NOT NULL DEFAULT 2 CHECK (weight BETWEEN 1 AND 3),
  PRIMARY KEY (opportunity_id, skill_id)
);

CREATE TABLE IF NOT EXISTS opportunity_careers (
  opportunity_id INTEGER NOT NULL REFERENCES opportunities(id) ON DELETE CASCADE,
  career_id      INTEGER NOT NULL REFERENCES careers(id)       ON DELETE CASCADE,
  PRIMARY KEY (opportunity_id, career_id)
);

CREATE TABLE IF NOT EXISTS opportunity_departments (
  opportunity_id INTEGER NOT NULL REFERENCES opportunities(id) ON DELETE CASCADE,
  department_id  INTEGER NOT NULL REFERENCES departments(id)   ON DELETE CASCADE,
  PRIMARY KEY (opportunity_id, department_id)
);

-- extra terms that mean a skill, so the auto-tagger can spot skills in free-text
-- job posts (e.g. "sklearn" -> machine-learning). Extendable via data/skill_aliases.csv.
CREATE TABLE IF NOT EXISTS skill_aliases (
  skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
  alias    TEXT NOT NULL,
  PRIMARY KEY (skill_id, alias)
);

-- one row per ingestion pass, per source: observability + a pilot validation metric
CREATE TABLE IF NOT EXISTS ingestion_runs (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  source     TEXT NOT NULL,
  fetched    INTEGER NOT NULL DEFAULT 0,
  inserted   INTEGER NOT NULL DEFAULT 0,
  updated    INTEGER NOT NULL DEFAULT 0,
  skipped    INTEGER NOT NULL DEFAULT 0,
  tagged     INTEGER NOT NULL DEFAULT 0,
  error      TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS saved_opportunities (
  student_id     INTEGER NOT NULL REFERENCES profiles(id)      ON DELETE CASCADE,
  opportunity_id INTEGER NOT NULL REFERENCES opportunities(id) ON DELETE CASCADE,
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (student_id, opportunity_id)
);

-- analytics backbone (pilot validation metrics)
CREATE TABLE IF NOT EXISTS events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id  INTEGER REFERENCES profiles(id) ON DELETE SET NULL,
  event_type  TEXT NOT NULL,
  entity_type TEXT,
  entity_id   TEXT,
  metadata    TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS feedback (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id     INTEGER REFERENCES profiles(id) ON DELETE SET NULL,
  clarity_before INTEGER,
  clarity_after  INTEGER,
  nps            INTEGER,
  comment        TEXT,
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);
