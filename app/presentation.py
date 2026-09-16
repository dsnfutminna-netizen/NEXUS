"""Testable presentation rules; no database access or UI side effects."""
import re
from datetime import date
from urllib.parse import urlsplit


def safe_url(value):
    try:
        parts = urlsplit(value or "")
        return value if parts.scheme in {"http", "https"} and parts.hostname and not parts.username else None
    except ValueError:
        return None


def is_sample(opp):
    host = urlsplit(safe_url(opp.get("url")) or "").hostname or ""
    return opp.get("source") == "sample" or any(
        host == domain or host.endswith("." + domain)
        for domain in ("example.org", "example.com", "example.net"))


def seniority(opp):
    title = opp["title"].lower()
    if re.search(r"\b(senior|sr\.?|lead|head|director|principal|architect)\b", title):
        return "Experienced roles"
    if re.search(r"\b(junior|intern|internship|graduate|student|entry)\b", title) or opp.get("category") in {"internship", "scholarship", "fellowship", "training", "hackathon"}:
        return "Student / early career"
    return "Not stated in title"


def expired(opp, today=None):
    try:
        return date.fromisoformat(str(opp.get("deadline") or "")[:10]) < (today or date.today())
    except ValueError:
        return False


def filter_matches(matches, by_slug, *, sample=False, query="", category="All", source="All", experience="All", career_only=False, career=None, saved_only=False, saved=(), sort="Skills coverage"):
    result = []
    for match in matches:
        opp = by_slug[match["slug"]]
        if is_sample(opp) != sample or expired(opp):
            continue
        if query.casefold() not in (opp["title"] + " " + (opp.get("organization") or "")).casefold():
            continue
        if category != "All" and opp.get("category") != category:
            continue
        if source != "All" and (opp.get("source") or "seed") != source:
            continue
        if experience != "All" and seniority(opp) != experience:
            continue
        if career_only and (not career or career not in opp.get("careers", set())):
            continue
        if saved_only and opp["id"] not in saved:
            continue
        result.append(match)
    if sort == "Deadline soonest":
        result.sort(key=lambda m: (m.get("deadline") or "9999-12-31", m["title"]))
    else:
        result.sort(key=lambda m: (-m["skill_match_pct"], m["title"]))
    return result
