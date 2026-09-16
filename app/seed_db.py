"""
NEXUS pilot database builder / seeder.

Run this once before launching the app:  python app/seed_db.py

What it does
------------
1. Creates app/../nexus.db from app/schema_sqlite.sql (idempotent).
2. Seeds the fixed taxonomies:
     - proficiency levels + industries + departments  (defined in code)
     - skill categories + skills                       (data/skill_taxonomy.csv)
     - careers                                         (data/careers.csv)
     - career_required_skills  "the answer key"        (data/career_skills.csv)
     - opportunities + their skill/career links        (data/opportunit*.csv)
3. Optionally seeds one demo student that reproduces the proposal's
   Data-Scientist example (login: demo@nexus.test / demo1234).

Re-running is safe: each table is only seeded when empty, so you can tweak a
CSV, delete nexus.db, and re-run to get a clean rebuild.
"""
import csv
import sys
from pathlib import Path

import db  # same folder

APP_DIR = Path(__file__).resolve().parent
DATA_DIR = APP_DIR.parent / "data"
SCHEMA_PATH = APP_DIR / "schema_sqlite.sql"
DB_PATH = db.DB_PATH


# --------------------------------------------------------------- code tables
PROFICIENCY_LEVELS = [
    (0, "none", "None", "No exposure yet."),
    (1, "beginner", "Beginner", "Basic awareness; needs guidance."),
    (2, "intermediate", "Intermediate", "Can work on tasks with some support."),
    (3, "advanced", "Advanced", "Works independently; can guide others."),
    (4, "expert", "Expert", "Deep expertise; the go-to person."),
]

INDUSTRIES = [
    "Technology & Software", "Financial Services & Fintech",
    "Healthcare & HealthTech", "Education & EdTech",
    "Agriculture & AgriTech", "E-commerce & Retail",
    "Telecommunications", "Energy & Power",
    "Government & Public Sector", "Media & Entertainment",
    "Consulting & Professional Services", "Manufacturing",
    "Transportation & Logistics", "Nonprofit & Social Impact",
]

# FUTMinna schools: SICT, SPS (Physical Sciences), SEET (Electrical Eng. & Tech.)
DEPARTMENTS = [
    ("Computer Science", "SICT"),
    ("Cyber Security Science", "SICT"),
    ("Information Technology", "SICT"),
    ("Information and Media Technology", "SICT"),
    ("Library and Information Technology", "SICT"),
    ("Mathematics", "SPS"),
    ("Statistics", "SPS"),
    ("Physics", "SPS"),
    ("Chemistry", "SPS"),
    ("Geology", "SPS"),
    ("Biological Sciences", "SPS"),
    ("Biochemistry", "SPS"),
    ("Electrical and Electronics Engineering", "SEET"),
    ("Computer Engineering", "SEET"),
    ("Telecommunication Engineering", "SEET"),
    ("Mechatronics Engineering", "SEET"),
]


def _read_csv(name):
    with open(DATA_DIR / name, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def _empty(conn, table):
    return conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0] == 0


def build_schema(conn):
    conn.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
    conn.commit()


# Columns added to `opportunities` after the pilot's first release. On an existing
# nexus.db, `CREATE TABLE IF NOT EXISTS` won't add them, so we ALTER them in before
# build_schema() tries to create the (source, external_id) index that needs them.
OPP_NEW_COLUMNS = [
    ("external_id", "TEXT"),
    ("location", "TEXT"),
    ("posted_at", "TEXT"),
    ("fetched_at", "TEXT"),
    ("tags", "TEXT"),
]


def migrate(conn):
    """Non-destructively bring an existing DB up to the current schema (safe on a fresh DB)."""
    have = {r["name"] for r in conn.execute("PRAGMA table_info(opportunities)")}
    if have:  # table exists; add any missing columns
        for col, typ in OPP_NEW_COLUMNS:
            if col not in have:
                conn.execute(f"ALTER TABLE opportunities ADD COLUMN {col} {typ}")
        conn.commit()


def seed_reference(conn):
    # ---- proficiency levels
    if _empty(conn, "proficiency_levels"):
        conn.executemany(
            "INSERT INTO proficiency_levels (rank, code, label, description) VALUES (?,?,?,?)",
            PROFICIENCY_LEVELS)

    # ---- industries
    if _empty(conn, "industries"):
        conn.executemany("INSERT INTO industries (name) VALUES (?)",
                         [(n,) for n in INDUSTRIES])

    # ---- departments
    if _empty(conn, "departments"):
        conn.executemany("INSERT INTO departments (name, faculty) VALUES (?,?)", DEPARTMENTS)

    # ---- skill categories + skills (from taxonomy CSV)
    if _empty(conn, "skills"):
        tax = _read_csv("skill_taxonomy.csv")
        for cat in dict.fromkeys(r["category"] for r in tax):          # preserve order, unique
            conn.execute("INSERT OR IGNORE INTO skill_categories (name) VALUES (?)", (cat,))
        cat_id = {r["name"]: r["id"]
                  for r in conn.execute("SELECT id, name FROM skill_categories")}
        conn.executemany(
            "INSERT INTO skills (name, slug, category_id) VALUES (?,?,?)",
            [(r["skill"], r["slug"], cat_id[r["category"]]) for r in tax])

    # ---- skill aliases (extra terms so the auto-tagger spots skills in free text)
    if _empty(conn, "skill_aliases"):
        skill_id = {r["slug"]: r["id"] for r in conn.execute("SELECT id, slug FROM skills")}
        rows = [(skill_id[r["skill_slug"]], r["alias"].strip().lower())
                for r in _read_csv("skill_aliases.csv") if r["skill_slug"] in skill_id]
        conn.executemany(
            "INSERT OR IGNORE INTO skill_aliases (skill_id, alias) VALUES (?,?)", rows)

    # ---- careers
    if _empty(conn, "careers"):
        conn.executemany(
            "INSERT INTO careers (slug, name, description) VALUES (?,?,?)",
            [(r["slug"], r["name"], r["description"]) for r in _read_csv("careers.csv")])

    # ---- career_required_skills  (the answer key; join slugs -> ids)
    if _empty(conn, "career_required_skills"):
        career_id = {r["slug"]: r["id"] for r in conn.execute("SELECT id, slug FROM careers")}
        skill_id = {r["slug"]: r["id"] for r in conn.execute("SELECT id, slug FROM skills")}
        rows = []
        for r in _read_csv("career_skills.csv"):
            rows.append((career_id[r["career_slug"]], skill_id[r["skill_slug"]],
                         int(r["target_rank"]), int(r["weight"])))
        conn.executemany(
            "INSERT INTO career_required_skills (career_id, skill_id, target_rank, weight)"
            " VALUES (?,?,?,?)", rows)

    # ---- opportunities + links
    if _empty(conn, "opportunities"):
        for r in _read_csv("opportunities.csv"):
            conn.execute("""
                INSERT INTO opportunities
                  (slug, title, category, organization, description, url,
                   is_remote, min_level, max_level, deadline, source)
                VALUES (?,?,?,?,?,?,?,?,?,?,?)
            """, (r["slug"], r["title"], r["category"], r["organization"] or None,
                  r["description"] or None, r["url"] or None,
                  int(r["is_remote"] or 0),
                  int(r["min_level"]) if r["min_level"] else None,
                  int(r["max_level"]) if r["max_level"] else None,
                  r["deadline"] or None, r["source"] or None))

        opp_id = {r["slug"]: r["id"] for r in conn.execute("SELECT id, slug FROM opportunities")}
        skill_id = {r["slug"]: r["id"] for r in conn.execute("SELECT id, slug FROM skills")}
        career_id = {r["slug"]: r["id"] for r in conn.execute("SELECT id, slug FROM careers")}

        conn.executemany(
            "INSERT INTO opportunity_skills (opportunity_id, skill_id, weight) VALUES (?,?,?)",
            [(opp_id[r["opp_slug"]], skill_id[r["skill_slug"]], int(r["weight"]))
             for r in _read_csv("opportunity_skills.csv")])

        conn.executemany(
            "INSERT INTO opportunity_careers (opportunity_id, career_id) VALUES (?,?)",
            [(opp_id[r["opp_slug"]], career_id[r["career_slug"]])
             for r in _read_csv("opportunity_careers.csv")])

    conn.commit()


# ------------------------------------------------------------- demo student
DEMO_EMAIL = "demo@nexus.test"
DEMO_PASSWORD = "demo1234"
# Reproduces the proposal's Data-Scientist worked example.
DEMO_SKILLS = {  # slug -> proficiency rank
    "python": 3, "statistics": 3, "sql": 1,
    "machine-learning": 1, "data-visualization": 2,
}


def seed_demo_student(conn):
    if conn.execute("SELECT 1 FROM profiles WHERE email=?", (DEMO_EMAIL,)).fetchone():
        return  # already there
    salt, pw_hash = db._hash_password(DEMO_PASSWORD)
    dept_id = conn.execute("SELECT id FROM departments WHERE name='Computer Science'").fetchone()[0]
    career_id = conn.execute("SELECT id FROM careers WHERE slug='data-scientist'").fetchone()[0]
    cur = conn.execute("""
        INSERT INTO profiles
          (full_name, email, password_salt, password_hash,
           department_id, level, cgpa, target_career_id, data_consent)
        VALUES (?,?,?,?,?,?,?,?,1)
    """, ("Demo Student", DEMO_EMAIL, salt, pw_hash, dept_id, 300, 3.75, career_id))
    sid = cur.lastrowid

    skill_id = {r["slug"]: r["id"] for r in conn.execute("SELECT id, slug FROM skills")}
    conn.executemany(
        "INSERT INTO student_skills (student_id, skill_id, proficiency_rank) VALUES (?,?,?)",
        [(sid, skill_id[slug], rank) for slug, rank in DEMO_SKILLS.items()])

    # one interest so the profile reads as complete
    ind = conn.execute("SELECT id FROM industries WHERE name='Technology & Software'").fetchone()[0]
    conn.execute("INSERT INTO student_interests (student_id, industry_id) VALUES (?,?)", (sid, ind))
    conn.commit()


def main(with_demo=True):
    fresh = not DB_PATH.exists()
    conn = db.get_conn()
    try:
        migrate(conn)        # upgrade an existing DB before (re)building the schema
        build_schema(conn)
        seed_reference(conn)
        if with_demo:
            seed_demo_student(conn)
    finally:
        conn.close()

    counts = {t: db.query(f"SELECT COUNT(*) AS n FROM {t}", one=True)["n"] for t in (
        "proficiency_levels", "skill_categories", "skills", "skill_aliases", "careers",
        "career_required_skills", "industries", "departments",
        "opportunities", "opportunity_skills", "opportunity_careers", "profiles")}
    print(("Created" if fresh else "Updated") + f" {DB_PATH}")
    for t, n in counts.items():
        print(f"  {t:<24} {n}")
    if with_demo:
        print(f"\nDemo login:  {DEMO_EMAIL}  /  {DEMO_PASSWORD}")


if __name__ == "__main__":
    main(with_demo="--no-demo" not in sys.argv)
