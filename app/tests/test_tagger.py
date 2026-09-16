"""
Correctness tests for the NEXUS auto-tagger (app/tagger.py).

Pure-function tests — no DB, no network. They lock in the behaviour that makes
the tags trustworthy: token-boundary matching (no substring false positives),
title-vs-body weighting, alias resolution, and career inference thresholds.

Run either way:
    python app/tests/test_tagger.py     # plain, zero deps, prints PASS/FAIL
    pytest app/tests/test_tagger.py      # if pytest is installed
"""
import sys
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(APP_DIR))

import tagger  # noqa: E402


# --------------------------------------------------------------- fixtures
SKILLS = [
    {"slug": "python", "name": "Python"},
    {"slug": "machine-learning", "name": "Machine Learning"},
    {"slug": "html-css", "name": "HTML & CSS"},
    {"slug": "javascript", "name": "JavaScript"},
    {"slug": "sql", "name": "SQL"},
    {"slug": "spreadsheets", "name": "Spreadsheets"},
    {"slug": "communication", "name": "Communication"},
]
ALIASES = [
    {"skill_slug": "machine-learning", "alias": "ml"},
    {"skill_slug": "machine-learning", "alias": "sklearn"},
    {"skill_slug": "html-css", "alias": "html"},
    {"skill_slug": "spreadsheets", "alias": "ms excel"},
]
CAREER_REQUIRED = {
    "data-scientist": [
        {"skill_slug": "python", "weight": 3},
        {"skill_slug": "machine-learning", "weight": 3},
        {"skill_slug": "sql", "weight": 2},
        {"skill_slug": "communication", "weight": 1},
    ],
    "frontend-developer": [
        {"skill_slug": "html-css", "weight": 3},
        {"skill_slug": "javascript", "weight": 3},
        {"skill_slug": "communication", "weight": 1},
    ],
}


def _index():
    return tagger.build_skill_index(SKILLS, ALIASES)


# ---------------------------------------------------------------------- tests
def test_index_covers_every_skill():
    idx = _index()
    assert {s["slug"] for s in idx} == {s["slug"] for s in SKILLS}
    # every skill compiled at least one matchable pattern (its own name)
    assert all(s["patterns"] for s in idx)


def test_body_match_gets_body_weight():
    tags = tagger.tag_skills("Intern", "You will use Python for analysis.", _index())
    assert tags["python"] == tagger.BODY_WEIGHT


def test_title_match_outranks_body():
    tags = tagger.tag_skills("Machine Learning Intern",
                             "Some Python and SQL required.", _index())
    assert tags["machine-learning"] == tagger.TITLE_WEIGHT   # in title
    assert tags["python"] == tagger.BODY_WEIGHT              # in body only
    assert tags["sql"] == tagger.BODY_WEIGHT


def test_alias_resolves_to_skill():
    tags = tagger.tag_skills("", "We use sklearn every day.", _index())
    assert "machine-learning" in tags


def test_ml_does_not_match_inside_html():
    # the substring 'ml' lives inside 'html' — token boundaries must prevent a false hit
    tags = tagger.tag_skills("", "Strong HTML skills required.", _index())
    assert "html-css" in tags
    assert "machine-learning" not in tags


def test_ms_excel_alias_not_triggered_by_verb_excel():
    hit = tagger.tag_skills("", "Comfort with MS Excel and dashboards.", _index())
    miss = tagger.tag_skills("", "Candidates who excel at teamwork.", _index())
    assert "spreadsheets" in hit
    assert "spreadsheets" not in miss


def test_infer_careers_picks_best_overlap():
    tags = {"python": 3, "machine-learning": 2, "sql": 2}   # all data-science skills
    careers = tagger.infer_careers(tags, CAREER_REQUIRED)
    assert careers[0] == "data-scientist"
    assert "frontend-developer" not in careers


def test_infer_careers_respects_min_score():
    # only a single weight-1 skill overlaps either career -> below threshold -> nothing
    tags = {"communication": 2}
    assert tagger.infer_careers(tags, CAREER_REQUIRED, min_score=4) == []


def test_infer_careers_drops_weak_secondary():
    # strong data-scientist (9) + a frontend match that clears min_score (4) but is
    # far weaker -> the dominance rule drops it rather than listing a spurious career.
    tags = {"python": 3, "machine-learning": 3, "sql": 2, "html-css": 3, "communication": 2}
    # data-scientist = 3+3+2+1 = 9 ; frontend = html-css(3)+communication(1) = 4  (< 0.5*9)
    assert tagger.infer_careers(tags, CAREER_REQUIRED) == ["data-scientist"]


def test_infer_careers_top_n_limit():
    # two comparably-strong careers (both 7) -> both survive dominance; top_n caps the list
    tags = {"python": 3, "machine-learning": 3, "html-css": 3, "javascript": 3, "communication": 2}
    assert tagger.infer_careers(tags, CAREER_REQUIRED, min_score=4, top_n=1) == ["data-scientist"]
    two = tagger.infer_careers(tags, CAREER_REQUIRED, min_score=4, top_n=2)
    assert set(two) == {"data-scientist", "frontend-developer"}
    assert two[0] == "data-scientist"   # tie broken by slug, listed first


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
