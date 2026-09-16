"""
NEXUS intelligence engine (pure Python, rule-based, transparent).

This is the SAME logic as the SQL views in db/schema.sql
(v_skill_gaps, v_opportunity_matches) — kept in Python so the pilot runs
anywhere, is unit-testable (see app/tests/test_intelligence.py), and can be
tuned by the ML/Intelligence team without touching the database.

Everything here is a pure function of plain dicts/lists — no DB, no Streamlit.
"""

PROFICIENCY = {0: "None", 1: "Beginner", 2: "Intermediate", 3: "Advanced", 4: "Expert"}

# Opportunity match weighting — documented and adjustable.
W_SKILLS = 0.65
W_CAREER = 0.20
W_ELIGIBILITY = 0.15


def gap_label(gap: int) -> str:
    if gap <= 0:
        return "On track"
    if gap == 1:
        return "Low"
    if gap == 2:
        return "Medium"
    return "High"


def compute_skill_gaps(student_skills: dict, career_required: list) -> list:
    """
    student_skills : {skill_slug: proficiency_rank(0..4)}
    career_required: [{skill_slug, skill_name, target_rank, weight}]
    returns rows sorted by priority (what to fix first), highest first.
    """
    rows = []
    for req in career_required:
        current = int(student_skills.get(req["skill_slug"], 0))
        target = int(req["target_rank"])
        weight = int(req["weight"])
        gap = max(target - current, 0)
        rows.append({
            "skill_slug": req["skill_slug"],
            "skill_name": req["skill_name"],
            "importance": weight,                 # 3 core, 2 important, 1 nice
            "target_rank": target,
            "current_rank": current,
            "target_label": PROFICIENCY[target],
            "current_label": PROFICIENCY[current],
            "gap": gap,
            "gap_label": gap_label(gap),
            "priority": gap * weight,             # fix big gaps on important skills first
        })
    rows.sort(key=lambda r: (-r["priority"], -r["importance"], r["skill_name"]))
    return rows


def compute_matches(student: dict, student_skills: dict, opportunities: list) -> list:
    """
    student        : {level, department_id, target_career_slug}
    student_skills : {skill_slug: rank}
    opportunities  : [{slug,title,category,deadline,url,organization,
                       min_level,max_level,
                       skills:[{slug,name,weight}],
                       careers:set(slug), departments:set(dept_id)}]
    returns rows sorted by match_score, highest first.
    Score = 65% skill overlap + 20% career alignment + 15% eligibility.
    """
    have = {slug for slug, rank in student_skills.items() if rank >= 1}
    s_level = student.get("level")
    s_dept = student.get("department_id")
    s_career = student.get("target_career_slug")

    results = []
    for opp in opportunities:
        opp_skills = opp.get("skills", [])
        total = sum(s["weight"] for s in opp_skills)
        if total == 0:
            continue  # nothing to match on

        matched = [s for s in opp_skills if s["slug"] in have]
        matched_weight = sum(s["weight"] for s in matched)
        skill_ratio = matched_weight / total

        min_l, max_l = opp.get("min_level"), opp.get("max_level")
        level_ok = ((min_l is None or (s_level is not None and s_level >= min_l))
                    and (max_l is None or (s_level is not None and s_level <= max_l)))

        depts = opp.get("departments") or set()
        dept_ok = (not depts) or (s_dept in depts)

        careers = opp.get("careers") or set()
        if not careers:
            career_align = 0.5
        elif s_career in careers:
            career_align = 1.0
        else:
            career_align = 0.0

        is_eligible = bool(level_ok and dept_ok)
        score = round(100 * (W_SKILLS * skill_ratio
                             + W_CAREER * career_align
                             + W_ELIGIBILITY * (1 if is_eligible else 0)))

        matched_names = [s["name"] for s in sorted(matched, key=lambda x: (-x["weight"], x["name"]))]

        results.append({
            "slug": opp.get("slug"),
            "title": opp["title"],
            "category": opp.get("category"),
            "organization": opp.get("organization"),
            "deadline": opp.get("deadline"),
            "url": opp.get("url"),
            "match_score": score,
            "skill_match_pct": round(100 * skill_ratio),
            "matched_skills": matched_names,
            "is_eligible": is_eligible,
        })

    results.sort(key=lambda r: (-r["match_score"], r["title"]))
    return results


def recommend_next_actions(gaps: list, top_n: int = 3) -> list:
    """Turn the biggest gaps into concrete next steps (decision support)."""
    focus = [g for g in gaps if g["gap"] > 0][:top_n]
    recs = []
    for g in focus:
        recs.append({
            "skill_name": g["skill_name"],
            "title": f"Level up {g['skill_name']}: {g['current_label']} → {g['target_label']}",
            "detail": (f"This is a {g['gap_label'].lower()}-priority gap for your target career. "
                       f"Pick one project or short course that uses {g['skill_name']} this month."),
            "priority": g["priority"],
            "gap_label": g["gap_label"],
        })
    return recs


def profile_completeness(sections_present: dict) -> int:
    """
    sections_present: booleans for the 6 profile sections
      department, level, cgpa, target_career, has_3_skills, has_interest
    returns 0..100 (mirrors v_profile_completeness).
    """
    keys = ["department", "level", "cgpa", "target_career", "has_3_skills", "has_interest"]
    done = sum(1 for k in keys if sections_present.get(k))
    return round(100 * done / len(keys))
