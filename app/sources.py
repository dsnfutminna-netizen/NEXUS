"""
NEXUS opportunity source adapters.

Each adapter knows how to pull raw postings from one place and normalise them to a
common shape the ingestion runner (app/ingest.py) understands. Adding a new source
= adding one class with a .fetch() method; nothing else changes.

Design rules:
  * Live adapters (HTTP) are best-effort: any network/parse error returns [] and is
    recorded, so ingestion never crashes and the app keeps working offline.
  * SampleFeedAdapter reads a local JSON file so the pipeline (and the bootcamp demo)
    always has fresh-looking external postings to tag, with zero network dependency.
  * Nigeria-specific items (DSN calls, scholarships, local internships) stay in the
    human-curated CSV feed loaded by seed_db.py — this module is for external sources.

Normalised posting keys:
  source, external_id, title, organization, description, url, category,
  is_remote, location, posted_at, deadline, tags(list)
"""
import json
import re
import urllib.parse
import urllib.request
from html import unescape
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
USER_AGENT = "NEXUS-DSN-FUTMinna/0.1 (student opportunity aggregator; contact: dsn-futminna)"
HTTP_TIMEOUT = 12

STUDENT_TERMS = ("intern", "junior", "graduate", "entry", "trainee", "apprentice",
                 "student", "fellow", "scholarship", "bootcamp", "early career")


# ------------------------------------------------------------------ helpers
def _http_get_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT,
                                               "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8", errors="replace"))


_TAG_RE = re.compile(r"<[^>]+>")
_WS_RE = re.compile(r"\s+")


def strip_html(text: str) -> str:
    if not text:
        return ""
    return _WS_RE.sub(" ", unescape(_TAG_RE.sub(" ", text))).strip()


def classify_category(title: str, tags) -> str:
    hay = (title + " " + " ".join(tags or [])).lower()
    if "scholarship" in hay:
        return "scholarship"
    if "fellow" in hay:
        return "fellowship"
    if "hackathon" in hay:
        return "hackathon"
    if "intern" in hay:
        return "internship"
    if any(t in hay for t in ("bootcamp", "training", "course")):
        return "training"
    return "job"


def is_student_relevant(title: str, tags) -> bool:
    hay = (title + " " + " ".join(tags or [])).lower()
    return any(t in hay for t in STUDENT_TERMS)


def _norm(source, external_id, title, organization, description, url,
          category=None, is_remote=1, location=None, posted_at=None,
          deadline=None, tags=None):
    tags = tags or []
    return {
        "source": source,
        "external_id": str(external_id) if external_id is not None else None,
        "title": title, "organization": organization,
        "description": description, "url": url,
        "category": category or classify_category(title, tags),
        "is_remote": int(bool(is_remote)),
        "location": location, "posted_at": posted_at, "deadline": deadline,
        "tags": tags,
    }


# ------------------------------------------------------------------ adapters
class SampleFeedAdapter:
    """Local fixture feed — guarantees the pipeline has data to tag, offline."""
    name = "sample"

    def __init__(self, path: Path = None):
        self.path = path or (DATA_DIR / "sample_feed.json")

    def fetch(self) -> list:
        if not self.path.exists():
            return []
        rows = json.loads(self.path.read_text(encoding="utf-8"))
        return [_norm(self.name, r.get("external_id"), r["title"], r.get("organization"),
                      r.get("description"), r.get("url"), r.get("category"),
                      r.get("is_remote", 1), r.get("location"), r.get("posted_at"),
                      r.get("deadline"), r.get("tags")) for r in rows]


class RemotiveAdapter:
    """remotive.com free API — remote tech roles. Query student-relevant searches."""
    name = "remotive"
    SEARCHES = ("intern", "junior developer", "data analyst", "graduate engineer")

    def fetch(self) -> list:
        out, seen = [], set()
        for term in self.SEARCHES:
            url = f"https://remotive.com/api/remote-jobs?search={urllib.parse.quote(term)}&limit=20"
            data = _http_get_json(url)
            for j in data.get("jobs", []):
                jid = str(j.get("id"))
                if jid in seen:
                    continue
                seen.add(jid)
                out.append(_norm(
                    self.name, jid, j.get("title", ""), j.get("company_name"),
                    strip_html(j.get("description")), j.get("url"),
                    category=classify_category(j.get("title", ""), j.get("tags")),
                    is_remote=1, location=j.get("candidate_required_location"),
                    posted_at=j.get("publication_date"), tags=j.get("tags")))
        return out


class RemoteOKAdapter:
    """remoteok.com free API — remote tech roles. Filtered to student-relevant."""
    name = "remoteok"

    def fetch(self) -> list:
        data = _http_get_json("https://remoteok.com/api")
        out = []
        for j in data:
            if not isinstance(j, dict) or not j.get("id") or not j.get("position"):
                continue  # first element is a legal/metadata notice
            title, tags = j.get("position", ""), j.get("tags", [])
            if not is_student_relevant(title, tags):
                continue
            out.append(_norm(
                self.name, j.get("id"), title, j.get("company"),
                strip_html(j.get("description")), j.get("url"),
                category=classify_category(title, tags),
                is_remote=1, location=j.get("location"),
                posted_at=j.get("date"), tags=tags))
        return out


# Live adapters attempted on every refresh, in order. SampleFeed is always included
# so the pipeline yields results even when the network is unavailable.
DEFAULT_ADAPTERS = [SampleFeedAdapter, RemotiveAdapter, RemoteOKAdapter]
OFFLINE_ADAPTERS = [SampleFeedAdapter]
