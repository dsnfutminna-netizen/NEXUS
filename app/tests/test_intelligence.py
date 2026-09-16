"""
Correctness tests for the NEXUS intelligence engine.

These reproduce the worked example from the NEXUS proposal (a Data-Science
student) using the *real* answer-key CSVs in data/, so they catch both
formula regressions and bad data edits.

Run either way:
    python app/tests/test_intelligence.py     # plain, zero deps, prints PASS/FAIL
    pytest app/tests/test_intelligence.py      # if pytest is installed
"""
import csv
import sys
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = APP_DIR.parent / "data"
sys.path.insert(0, str(APP_DIR))          # import the engine without installing anything

import intelligence as ai  # noqa: E402


# --------------------------------------------------------------- data loaders
def _csv(name):
    with open(DATA_DIR / name, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def skill_names():
    return {r["slug"]: r["skill"] for r in _csv("skill_taxonomy.csv")}


def career_required(career_slug):
    names = skill_names()
    return [{"skill_slug": r["skill_slug"],
             "skill_name": names[r["skill_slug"]],
             "target_rank": int(r["target_rank"]),
             "weight": int(r["weight"])}
            for r in _csv("career_skills.csv") if r["career_slug"] == career_slug]


def opportunities():
    names = skill_names()
    opps = {}
    for r in _csv("opportunities.csv"):
        opps[r["slug"]] = {
            "slug": r["slug"], "title": r["title"], "category": r["category"],
            "organization": r["organization"], "deadline": r["deadline"], "url": r["url"],
            "min_level": int(r["min_level"]) if r["min_level"] else None,
            "max_level": int(r["max_level"]) if r["max_level"] else None,
            "skills": [], "careers": set(), "departments": set(),
        }
    for r in _csv("opportunity_skills.csv"):
        opps[r["opp_slug"]]["skills"].append(
            {"slug": r["skill_slug"], "name": names[r["skill_slug"]], "weight": int(r["weight"])})
    for r in _csv("opportunity_careers.csv"):
        opps[r["opp_slug"]]["careers"].add(r["career_slug"])
    return list(opps.values())


# The proposal's demo student.
DEMO_SKILLS = {"python": 3, "statistics": 3, "sql": 1, "machine-learning": 1, "data-visualization": 2}
DEMO_STUDENT = {"level": 300, "department_id": 1, "target_career_slug": "data-scientist"}


# ---------------------------------------------------------------------- tests
def test_top_gap_is_data_analysis():
    gaps = ai.compute_skill_gaps(DEMO_SKILLS, career_required("data-scientist"))
    top = gaps[0]
    assert top["skill_slug"] == "data-analysis"
    assert top["current_rank"] == 0
    assert top["target_rank"] == 3
    assert top["gap"] == 3
    assert top["importance"] == 3
    assert top["priority"] == 9
    assert top["gap_label"] == "High"


def test_gaps_sorted_by_priority_desc():
    gaps = ai.compute_skill_gaps(DEMO_SKILLS, career_required("data-scientist"))
    priorities = [g["priority"] for g in gaps]
    assert priorities == sorted(priorities, reverse=True)


def test_mastered_skills_are_on_track():
    gaps = {g["skill_slug"]: g for g in
            ai.compute_skill_gaps(DEMO_SKILLS, career_required("data-scientist"))}
    assert gaps["python"]["gap"] == 0
    assert gaps["python"]["gap_label"] == "On track"
    assert gaps["statistics"]["gap"] == 0


def test_dsn_internship_is_perfect_match():
    matches = {m["slug"]: m for m in
               ai.compute_matches(DEMO_STUDENT, DEMO_SKILLS, opportunities())}
    dsn = matches["dsn-ds-internship"]
    assert dsn["match_score"] == 100
    assert dsn["skill_match_pct"] == 100
    assert dsn["is_eligible"] is True
    # "why it matches" must list every one of the student's matched skills
    assert set(dsn["matched_skills"]) == {
        "Python", "Statistics", "SQL", "Machine Learning", "Data Visualization"}


def test_match_scores_and_ranking():
    ranked = ai.compute_matches(DEMO_STUDENT, DEMO_SKILLS, opportunities())
    scores = {m["slug"]: m["match_score"] for m in ranked}
    assert scores["dsn-ds-internship"] == 100
    assert scores["ai-eng-fellowship"] == 30      # only Python overlaps + eligible
    assert scores["futminna-frontend-hack"] == 15  # eligibility only
    assert scores["product-design-bootcamp"] == 15
    assert scores["growth-marketing-internship"] == 15
    # highest first, ties broken by title
    assert ranked[0]["slug"] == "dsn-ds-internship"
    assert ranked[1]["slug"] == "ai-eng-fellowship"
    assert [m["slug"] for m in ranked[2:]] == [
        "futminna-frontend-hack", "growth-marketing-internship", "product-design-bootcamp"]


def test_next_actions_lead_with_top_gap():
    gaps = ai.compute_skill_gaps(DEMO_SKILLS, career_required("data-scientist"))
    recs = ai.recommend_next_actions(gaps, top_n=3)
    assert len(recs) == 3
    assert recs[0]["skill_name"] == "Data Analysis"
    assert recs[0]["gap_label"] == "High"


def test_profile_completeness_scale():
    assert ai.profile_completeness({}) == 0
    assert ai.profile_completeness({k: True for k in
        ["department", "level", "cgpa", "target_career", "has_3_skills", "has_interest"]}) == 100
    assert ai.profile_completeness({"department": True, "level": True, "cgpa": True}) == 50


# --------------------------------------------------------------- plain runner
def _main():
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    passed = 0
    for t in tests:
        try:
            t()
            print(f"  PASS  {t.__name__}")
            passed += 1
        except AssertionError as e:
            print(f"  FAIL  {t.__name__}: {e}")
        except Exception as e:  # noqa: BLE001
            print(f"  ERROR {t.__name__}: {type(e).__name__}: {e}")
    print(f"\n{passed}/{len(tests)} tests passed")
    return passed == len(tests)


if __name__ == "__main__":
    sys.exit(0 if _main() else 1)
