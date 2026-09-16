"""
NEXUS opportunity ingestion runner.

Pulls postings from each source adapter (app/sources.py), auto-tags them into the
fixed skill taxonomy (app/tagger.py), infers matching careers, and upserts them into
nexus.db — deduping on (source, external_id). Every pass is recorded in
`ingestion_runs` for observability.

Usage
-----
    python app/ingest.py            # live APIs + local sample feed
    python app/ingest.py --offline  # local sample feed only (no network)

Designed so the Streamlit app can call run_ingest() directly from a "Refresh
opportunities" button. Network failures degrade gracefully: a failing adapter is
logged with its error and the others (and the offline sample feed) still run.
"""
import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import db          # noqa: E402
import tagger      # noqa: E402
import sources     # noqa: E402


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def run_ingest(offline: bool = False, adapters=None, db_path: Path = None, verbose: bool = True) -> dict:
    """
    Fetch -> tag -> infer -> upsert for each adapter. Returns aggregate totals.
    A posting with no recognised taxonomy skill is skipped (it couldn't be matched).
    """
    db_path = db_path or db.DB_PATH
    fetched_at = _now_iso()

    # Build the tagging context once (cheap, and stable across all adapters this run).
    skills, aliases = db.get_skills_for_tagger(db_path)
    skill_index = tagger.build_skill_index(skills, aliases)
    career_required = db.get_career_required_map(db_path)

    adapter_classes = adapters or (
        sources.OFFLINE_ADAPTERS if offline else sources.DEFAULT_ADAPTERS)
    totals = {"fetched": 0, "inserted": 0, "updated": 0, "skipped": 0, "tagged": 0}

    for cls in adapter_classes:
        adapter = cls()
        name = getattr(adapter, "name", cls.__name__)
        run = {"fetched": 0, "inserted": 0, "updated": 0, "skipped": 0, "tagged": 0}
        error = None
        try:
            postings = adapter.fetch()
            run["fetched"] = len(postings)
            for p in postings:
                skill_tags = tagger.tag_skills(p.get("title", ""), p.get("description", ""),
                                               skill_index)
                if not skill_tags:
                    run["skipped"] += 1        # nothing in our taxonomy -> can't match it
                    continue
                careers = tagger.infer_careers(skill_tags, career_required)
                opp_id, status = db.upsert_opportunity(p, fetched_at, db_path)
                db.set_opportunity_skills(opp_id, skill_tags, db_path)
                db.set_opportunity_careers(opp_id, careers, db_path)
                run[status] += 1
                run["tagged"] += 1
        except Exception as e:  # network/parse/etc — log it, keep the pipeline alive
            error = f"{type(e).__name__}: {e}"

        db.log_ingestion_run(name, run["fetched"], run["inserted"], run["updated"],
                             run["skipped"], run["tagged"], error, db_path)
        for k in totals:
            totals[k] += run[k]
        if verbose:
            detail = error or (f"{run['inserted']} new, {run['updated']} updated, "
                               f"{run['skipped']} skipped (no skills matched)")
            print(f"  [{name:<9}] fetched {run['fetched']:>3}  ->  {detail}")
    return totals


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Ingest opportunities into nexus.db")
    ap.add_argument("--offline", action="store_true",
                    help="use only the local sample feed (no network calls)")
    args = ap.parse_args(argv)

    if not db.DB_PATH.exists():
        print("nexus.db not found — run this first:  python app/seed_db.py")
        return 1

    print(f"Ingesting opportunities ({'offline (sample only)' if args.offline else 'live APIs + sample'})...")
    totals = run_ingest(offline=args.offline)
    print(f"\nTotal: {totals['inserted']} new, {totals['updated']} updated, "
          f"{totals['tagged']} tagged, {totals['skipped']} skipped, {totals['fetched']} fetched.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
