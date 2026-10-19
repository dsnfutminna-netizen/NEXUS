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
import time
import urllib.parse
import urllib.request
from html import unescape
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
USER_AGENT = "NEXUS-DSN-FUTMinna/0.1 (student opportunity aggregator; contact: dsnfutminna@datascientistsfoundation.org)"
HTTP_TIMEOUT = 12

STUDENT_TERMS = ("intern", "junior", "graduate", "entry", "trainee", "apprentice",
                 "student", "fellow", "scholarship", "bootcamp", "early career")


# ------------------------------------------------------------------ helpers
def _http_get_json(url: str, attempts: int = 2):
    # Bounded retry: a transient network blip shouldn't cost us a day's feed.
    last = None
    for i in range(attempts):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT,
                                                       "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
                return json.loads(resp.read().decode("utf-8", errors="replace"))
        except Exception as e:
            last = e
            time.sleep(0.5 * (i + 1))
    raise last


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
    if re.search(r"\b(senior|sr|lead|manager|director|principal|head)\b", title.lower()):
        return False
    return any(re.search(r"\b" + re.escape(t) + r"\b", hay) for t in STUDENT_TERMS)


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
            try:
                data = _http_get_json(url)
            except Exception:
                continue  # one failed search must not drop the others
            for j in data.get("jobs", []):
                jid = str(j.get("id"))
                if jid in seen or not is_student_relevant(j.get("title", ""), []):
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
            if not is_student_relevant(title, []):
                continue
            out.append(_norm(
                self.name, j.get("id"), title, j.get("company"),
                strip_html(j.get("description")), j.get("url"),
                category=classify_category(title, tags),
                is_remote=1, location=j.get("location"),
                posted_at=j.get("date"), tags=tags))
        return out


class JobicyAdapter:
    """Jobicy's public, attributed feed of recently published remote jobs.

    The `anywhere` filter avoids importing posts limited to a region that
    excludes Nigeria. Jobicy's feed covers the last seven days only, so a
    missing item is not evidence that its application has closed.
    """
    name = "jobicy"

    def fetch(self) -> list:
        data = _http_get_json(
            "https://jobicy.com/api/v2/remote-jobs?count=200&geo=anywhere"
        )
        out = []
        for job in data.get("jobs", []):
            if not isinstance(job, dict):
                continue
            title = job.get("jobTitle") or ""
            level = str(job.get("jobLevel") or "").lower()
            job_types = job.get("jobType") or []
            if not job.get("id") or not title:
                continue
            if any(term in level for term in ("senior", "lead", "principal", "director")):
                continue
            if not (is_student_relevant(title, []) or
                    any(term in level for term in ("entry", "junior", "intern", "graduate"))):
                continue
            description = strip_html(job.get("jobDescription") or job.get("jobExcerpt") or "")
            out.append(_norm(
                self.name, job["id"], title, job.get("companyName"),
                description, job.get("url"),
                category=classify_category(title, job_types), is_remote=1,
                location=job.get("jobGeo") or "Anywhere",
                posted_at=job.get("pubDate"), tags=job.get("jobIndustry") or [],
            ))
        return out


def configured_boards(path: Path = None):
    """Only named public Greenhouse/Lever boards; never fetch arbitrary URLs."""
    path = path or DATA_DIR / "opportunity_boards.json"
    if not path.exists():
        return []
    boards = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(boards, list):
        raise ValueError("opportunity_boards.json must be an array")
    for board in boards:
        if (not isinstance(board, dict) or
                board.get("platform") not in ("greenhouse", "lever") or
                not re.fullmatch(r"[A-Za-z0-9_-]{2,80}", str(board.get("board", ""))) or
                not isinstance(board.get("organization"), str) or
                not board["organization"].strip()):
            raise ValueError("Invalid opportunity board configuration")
    return boards


class OrganizationBoardsAdapter:
    """Read published positions from explicitly configured organization boards."""
    name = "organization_boards"

    def fetch(self) -> list:
        out = []
        for board in configured_boards():
            platform, token = board["platform"], board["board"]
            try:
                if platform == "greenhouse":
                    data = _http_get_json(
                        f"https://boards-api.greenhouse.io/v1/boards/{token}/jobs?content=true"
                    )
                    for job in data.get("jobs", []):
                        title = job.get("title") or ""
                        if not job.get("id") or not is_student_relevant(title, []):
                            continue
                        out.append(_norm(
                            "greenhouse", f"{token}:{job['id']}", title,
                            board["organization"], strip_html(job.get("content") or ""),
                            job.get("absolute_url"), is_remote=False,
                            location=(job.get("location") or {}).get("name"),
                            posted_at=job.get("updated_at"),
                        ))
                else:
                    data = _http_get_json(
                        f"https://api.lever.co/v0/postings/{token}?mode=json&limit=100"
                    )
                    for job in data if isinstance(data, list) else []:
                        title = job.get("text") or ""
                        if not job.get("id") or not is_student_relevant(title, []):
                            continue
                        categories = job.get("categories") or {}
                        out.append(_norm(
                            "lever", f"{token}:{job['id']}", title,
                            board["organization"],
                            strip_html(job.get("descriptionPlain") or job.get("description") or ""),
                            job.get("hostedUrl"), is_remote="remote" in
                            str(categories.get("location") or "").lower(),
                            location=categories.get("location"),
                            tags=[str(categories.get("team") or "")],
                        ))
            except Exception:
                # One temporarily unavailable organization's board must not
                # prevent other sources from being collected.
                continue
        return out


# Live adapters attempted on every refresh, in order. SampleFeed is always included
# so the pipeline yields results even when the network is unavailable.
DEFAULT_ADAPTERS = [SampleFeedAdapter, RemotiveAdapter, RemoteOKAdapter,
                    JobicyAdapter, OrganizationBoardsAdapter]
OFFLINE_ADAPTERS = [SampleFeedAdapter]
