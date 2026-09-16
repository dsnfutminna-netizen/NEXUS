"""
NEXUS data-access layer (SQLite for the pilot).

Keeps all SQL in one place so the UI (app.py) stays clean and the
Backend/Data-Engineering team has a single file to port to Supabase later.
"""
import sqlite3
import hashlib
import hmac
import os
import re
import binascii
import json
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
ROOT_DIR = APP_DIR.parent
DATA_DIR = ROOT_DIR / "data"
SCHEMA_PATH = APP_DIR / "schema_sqlite.sql"
DB_PATH = Path(os.environ.get("NEXUS_DB_PATH", str(ROOT_DIR / "nexus.db")))


def get_conn(db_path: Path = DB_PATH) -> sqlite3.Connection:
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def query(sql, params=(), one=False, db_path: Path = DB_PATH):
    conn = get_conn(db_path)
    try:
        rows = conn.execute(sql, params).fetchall()
        return (rows[0] if rows else None) if one else rows
    finally:
        conn.close()


def execute(sql, params=(), db_path: Path = DB_PATH):
    conn = get_conn(db_path)
    try:
        cur = conn.execute(sql, params)
        conn.commit()
        return cur.lastrowid
    finally:
        conn.close()


# ------------------------------------------------------------------ auth
def _hash_password(password: str, salt: bytes = None):
    if salt is None:
        salt = os.urandom(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100_000)
    return binascii.hexlify(salt).decode(), binascii.hexlify(dk).decode()


def create_user(full_name: str, email: str, password: str) -> int:
    email = email.strip().lower()
    if not full_name.strip() or not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email) or len(password) < 6:
        raise ValueError("Enter your name, a valid email, and a password of at least 6 characters.")
    if query("SELECT 1 FROM profiles WHERE email = ?", (email,), one=True):
        raise ValueError("An account with that email already exists.")
    salt, pw_hash = _hash_password(password)
    return execute(
        "INSERT INTO profiles (full_name, email, password_salt, password_hash) VALUES (?,?,?,?)",
        (full_name.strip(), email, salt, pw_hash),
    )


def authenticate(email: str, password: str):
    row = query("SELECT * FROM profiles WHERE email = ?", (email.strip().lower(),), one=True)
    if not row:
        return None
    _, check = _hash_password(password, binascii.unhexlify(row["password_salt"]))
    return row if hmac.compare_digest(check, row["password_hash"]) else None


# -------------------------------------------------------------- reference
# NOTE: these return plain dicts (not sqlite3.Row) so Streamlit can use them
# directly as widget options — Row objects aren't picklable.
def get_departments():
    return [dict(r) for r in query("SELECT id, name, faculty FROM departments ORDER BY name")]


def get_industries():
    return [dict(r) for r in query("SELECT id, name FROM industries ORDER BY name")]


def get_careers():
    return [dict(r) for r in
            query("SELECT id, slug, name, description FROM careers WHERE is_active=1 ORDER BY name")]


def get_proficiency_levels():
    return [dict(r) for r in query("SELECT rank, label FROM proficiency_levels ORDER BY rank")]


def get_skills_by_category():
    rows = query("""
        SELECT c.name AS category, s.id, s.name, s.slug
        FROM skills s JOIN skill_categories c ON c.id = s.category_id
        WHERE s.is_active = 1
        ORDER BY c.name, s.name
    """)
    grouped = {}
    for r in rows:
        grouped.setdefault(r["category"], []).append(dict(r))
    return grouped


def get_career_required(career_id: int):
    rows = query("""
        SELECT s.slug AS skill_slug, s.name AS skill_name,
               crs.target_rank, crs.weight
        FROM career_required_skills crs
        JOIN skills s ON s.id = crs.skill_id
        WHERE crs.career_id = ?
    """, (career_id,))
    return [dict(r) for r in rows]


# ---------------------------------------------------------------- profile
def get_profile(user_id: int):
    return query("SELECT * FROM profiles WHERE id = ?", (user_id,), one=True)


def get_target_career_slug(user_id: int):
    row = query("""
        SELECT c.slug FROM profiles p JOIN careers c ON c.id = p.target_career_id
        WHERE p.id = ?
    """, (user_id,), one=True)
    return row["slug"] if row else None


def update_academic(user_id, department_id, level, cgpa, target_career_id, consent):
    execute("""
        UPDATE profiles
        SET department_id=?, level=?, cgpa=?, target_career_id=?, data_consent=?,
            updated_at=datetime('now')
        WHERE id=?
    """, (department_id, level, cgpa, target_career_id, 1 if consent else 0, user_id))


def set_student_skills(user_id: int, skill_ranks: dict):
    """skill_ranks: {skill_id: rank}. rank 0 removes the row."""
    conn = get_conn()
    try:
        for skill_id, rank in skill_ranks.items():
            if rank and rank > 0:
                conn.execute("""
                    INSERT INTO student_skills (student_id, skill_id, proficiency_rank)
                    VALUES (?,?,?)
                    ON CONFLICT(student_id, skill_id)
                    DO UPDATE SET proficiency_rank=excluded.proficiency_rank,
                                  updated_at=datetime('now')
                """, (user_id, skill_id, rank))
            else:
                conn.execute("DELETE FROM student_skills WHERE student_id=? AND skill_id=?",
                             (user_id, skill_id))
        conn.commit()
    finally:
        conn.close()


def get_student_skill_ranks_by_slug(user_id: int) -> dict:
    rows = query("""
        SELECT s.slug, ss.proficiency_rank
        FROM student_skills ss JOIN skills s ON s.id = ss.skill_id
        WHERE ss.student_id = ?
    """, (user_id,))
    return {r["slug"]: r["proficiency_rank"] for r in rows}


def get_student_skill_ranks_by_id(user_id: int) -> dict:
    rows = query("SELECT skill_id, proficiency_rank FROM student_skills WHERE student_id=?", (user_id,))
    return {r["skill_id"]: r["proficiency_rank"] for r in rows}


def count_student_skills(user_id: int) -> int:
    return query("SELECT COUNT(*) AS n FROM student_skills WHERE student_id=?", (user_id,), one=True)["n"]


def set_interests(user_id: int, industry_ids: list):
    conn = get_conn()
    try:
        conn.execute("DELETE FROM student_interests WHERE student_id=?", (user_id,))
        conn.executemany("INSERT INTO student_interests (student_id, industry_id) VALUES (?,?)",
                         [(user_id, i) for i in industry_ids])
        conn.commit()
    finally:
        conn.close()


def get_interest_ids(user_id: int) -> list:
    return [r["industry_id"] for r in
            query("SELECT industry_id FROM student_interests WHERE student_id=?", (user_id,))]


# ----------------------------------------------------------- opportunities
def get_opportunities_for_matching():
    """Assemble the structure app/intelligence.compute_matches expects."""
    opps = {r["id"]: dict(r) for r in query("SELECT * FROM opportunities WHERE is_active=1")}
    for o in opps.values():
        o["skills"], o["careers"], o["departments"] = [], set(), set()

    for r in query("""
        SELECT os.opportunity_id, s.slug, s.name, os.weight
        FROM opportunity_skills os JOIN skills s ON s.id = os.skill_id
    """):
        if r["opportunity_id"] in opps:
            opps[r["opportunity_id"]]["skills"].append(
                {"slug": r["slug"], "name": r["name"], "weight": r["weight"]})

    for r in query("""
        SELECT oc.opportunity_id, c.slug FROM opportunity_careers oc
        JOIN careers c ON c.id = oc.career_id
    """):
        if r["opportunity_id"] in opps:
            opps[r["opportunity_id"]]["careers"].add(r["slug"])

    for r in query("SELECT opportunity_id, department_id FROM opportunity_departments"):
        if r["opportunity_id"] in opps:
            opps[r["opportunity_id"]]["departments"].add(r["department_id"])

    # Recompute inferred live-feed tags so rule corrections reach already
    # fetched listings without overwriting the user's database or curated tags.
    import tagger
    skills, aliases = get_skills_for_tagger()
    index = tagger.build_skill_index(skills, aliases)
    names = {s["slug"]: s["name"] for s in skills}
    required_map = get_career_required_map()
    for opp in opps.values():
        if opp.get("source") in {"remotive", "remoteok"}:
            tags = tagger.tag_skills(opp["title"], opp.get("description"), index)
            opp["skills"] = [{"slug": slug, "name": names[slug], "weight": weight} for slug, weight in tags.items()]
            opp["careers"] = set(tagger.infer_careers(tags, required_map))
    return list(opps.values())


def toggle_saved(user_id: int, opportunity_id: int) -> bool:
    exists = query("SELECT 1 FROM saved_opportunities WHERE student_id=? AND opportunity_id=?",
                   (user_id, opportunity_id), one=True)
    if exists:
        execute("DELETE FROM saved_opportunities WHERE student_id=? AND opportunity_id=?",
                (user_id, opportunity_id))
        return False
    execute("INSERT INTO saved_opportunities (student_id, opportunity_id) VALUES (?,?)",
            (user_id, opportunity_id))
    return True


def get_saved_ids(user_id: int) -> set:
    return {r["opportunity_id"] for r in
            query("SELECT opportunity_id FROM saved_opportunities WHERE student_id=?", (user_id,))}


# ----------------------------------------------------- ingestion (see ingest.py)
def _slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")
    return slug or "opp"


def _unique_slug(conn, base: str) -> str:
    """A slug not yet used in opportunities (slug is UNIQUE)."""
    root = _slugify(base)
    candidate, i = root, 2
    while conn.execute("SELECT 1 FROM opportunities WHERE slug=?", (candidate,)).fetchone():
        candidate, i = f"{root}-{i}", i + 1
    return candidate


def upsert_opportunity(posting: dict, fetched_at: str, db_path: Path = DB_PATH):
    """
    Insert or update one normalised posting (from sources.py), deduping on
    (source, external_id). Returns (opportunity_id, "inserted"|"updated").
    Curated CSV rows (external_id NULL) are never touched here.
    """
    conn = get_conn(db_path)
    try:
        source, external_id = posting.get("source"), posting.get("external_id")
        tags = posting.get("tags") or []
        tags_str = ",".join(map(str, tags)) if isinstance(tags, (list, tuple)) else str(tags)
        row = None
        if external_id is not None:
            row = conn.execute("SELECT id FROM opportunities WHERE source=? AND external_id=?",
                               (source, external_id)).fetchone()
        if row:
            opp_id = row["id"]
            conn.execute("""
                UPDATE opportunities SET
                  title=?, category=?, organization=?, description=?, url=?,
                  is_remote=?, location=?, posted_at=?, deadline=?, tags=?,
                  fetched_at=?, is_active=1
                WHERE id=?
            """, (posting["title"], posting["category"], posting.get("organization"),
                  posting.get("description"), posting.get("url"),
                  int(bool(posting.get("is_remote", 0))), posting.get("location"),
                  posting.get("posted_at"), posting.get("deadline"), tags_str,
                  fetched_at, opp_id))
            status = "updated"
        else:
            base = f"{source}-{external_id}" if external_id else posting["title"]
            slug = _unique_slug(conn, base)
            cur = conn.execute("""
                INSERT INTO opportunities
                  (slug, title, category, organization, description, url, is_remote,
                   deadline, is_active, source, external_id, location, posted_at,
                   fetched_at, tags)
                VALUES (?,?,?,?,?,?,?,?,1,?,?,?,?,?,?)
            """, (slug, posting["title"], posting["category"], posting.get("organization"),
                  posting.get("description"), posting.get("url"),
                  int(bool(posting.get("is_remote", 0))), posting.get("deadline"),
                  source, external_id, posting.get("location"),
                  posting.get("posted_at"), fetched_at, tags_str))
            opp_id, status = cur.lastrowid, "inserted"
        conn.commit()
        return opp_id, status
    finally:
        conn.close()


def set_opportunity_skills(opportunity_id: int, skill_weights: dict, db_path: Path = DB_PATH) -> int:
    """Replace an opportunity's skill links. skill_weights: {skill_slug: weight}."""
    conn = get_conn(db_path)
    try:
        skill_id = {r["slug"]: r["id"] for r in conn.execute("SELECT id, slug FROM skills")}
        conn.execute("DELETE FROM opportunity_skills WHERE opportunity_id=?", (opportunity_id,))
        rows = [(opportunity_id, skill_id[slug], int(w))
                for slug, w in skill_weights.items() if slug in skill_id]
        conn.executemany(
            "INSERT INTO opportunity_skills (opportunity_id, skill_id, weight) VALUES (?,?,?)", rows)
        conn.commit()
        return len(rows)
    finally:
        conn.close()


def set_opportunity_careers(opportunity_id: int, career_slugs: list, db_path: Path = DB_PATH) -> int:
    """Replace an opportunity's career links."""
    conn = get_conn(db_path)
    try:
        career_id = {r["slug"]: r["id"] for r in conn.execute("SELECT id, slug FROM careers")}
        conn.execute("DELETE FROM opportunity_careers WHERE opportunity_id=?", (opportunity_id,))
        rows = [(opportunity_id, career_id[s]) for s in career_slugs if s in career_id]
        conn.executemany(
            "INSERT INTO opportunity_careers (opportunity_id, career_id) VALUES (?,?)", rows)
        conn.commit()
        return len(rows)
    finally:
        conn.close()


def get_skills_for_tagger(db_path: Path = DB_PATH):
    """(skills, aliases) shaped for tagger.build_skill_index."""
    skills = [dict(r) for r in
              query("SELECT slug, name FROM skills WHERE is_active=1", db_path=db_path)]
    aliases = [{"skill_slug": r["slug"], "alias": r["alias"]} for r in
               query("""SELECT s.slug, a.alias FROM skill_aliases a
                        JOIN skills s ON s.id = a.skill_id""", db_path=db_path)]
    return skills, aliases


def get_career_required_map(db_path: Path = DB_PATH) -> dict:
    """{career_slug: [{"skill_slug","weight"}, ...]} — the answer key for infer_careers."""
    rows = query("""
        SELECT c.slug AS career_slug, s.slug AS skill_slug, crs.weight
        FROM career_required_skills crs
        JOIN careers c ON c.id = crs.career_id
        JOIN skills  s ON s.id = crs.skill_id
    """, db_path=db_path)
    out = {}
    for r in rows:
        out.setdefault(r["career_slug"], []).append(
            {"skill_slug": r["skill_slug"], "weight": r["weight"]})
    return out


def log_ingestion_run(source, fetched=0, inserted=0, updated=0, skipped=0,
                      tagged=0, error=None, db_path: Path = DB_PATH):
    execute("""INSERT INTO ingestion_runs
                 (source, fetched, inserted, updated, skipped, tagged, error)
               VALUES (?,?,?,?,?,?,?)""",
            (source, fetched, inserted, updated, skipped, tagged, error), db_path=db_path)


def get_ingestion_summary(db_path: Path = DB_PATH) -> dict:
    """Freshness signal for the UI: how many external postings and when last fetched."""
    row = query("""SELECT COUNT(*) AS n, MAX(fetched_at) AS last_fetched
                   FROM opportunities WHERE external_id IS NOT NULL AND is_active=1""",
                one=True, db_path=db_path)
    return {"count": row["n"] if row else 0, "last_fetched": row["last_fetched"] if row else None}


# -------------------------------------------------------- analytics/feedback
def log_event(user_id, event_type, entity_type=None, entity_id=None, metadata=None):
    execute("""INSERT INTO events (student_id, event_type, entity_type, entity_id, metadata)
               VALUES (?,?,?,?,?)""",
            (user_id, event_type, entity_type, str(entity_id) if entity_id is not None else None,
             json.dumps(metadata) if metadata else None))


def save_feedback(user_id, clarity_before, clarity_after, nps, comment):
    execute("""INSERT INTO feedback (student_id, clarity_before, clarity_after, nps, comment)
               VALUES (?,?,?,?,?)""",
            (user_id, clarity_before, clarity_after, nps, comment))
