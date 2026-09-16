"""
NEXUS auto-tagger — maps a free-text opportunity into the fixed skill taxonomy.

This is the "intelligent" part of ingestion: a raw job/scholarship posting comes
in as plain text, and we turn it into structured skill + career tags that the
matching engine (app/intelligence.py) can score against. Rule-based and
transparent on purpose — every tag is explainable ("we matched 'sklearn' -> Machine
Learning"), which is what lets students trust the results.

Pure functions over plain data — no DB, no network (see app/tests/test_tagger.py).
"""
import re

# alias -> skill weighting: a hit in the TITLE is a stronger signal than in the body.
TITLE_WEIGHT = 3
BODY_WEIGHT = 2


def build_skill_index(skills: list, aliases: list) -> list:
    """
    skills  : [{"slug","name"}]
    aliases : [{"skill_slug","alias"}]
    returns : [{"slug","name","patterns":[compiled regex,...]}]
    Each term is matched on token boundaries that tolerate symbols (c++, node.js,
    a/b testing) and won't fire inside longer words ('ml' will not match 'html').
    """
    terms_by_slug = {}
    for s in skills:
        # the skill's own name is a term too (slug hyphens -> spaces covers multiword)
        terms_by_slug.setdefault(s["slug"], {"name": s["name"], "terms": set()})
        terms_by_slug[s["slug"]]["terms"].add(s["name"].lower())
        terms_by_slug[s["slug"]]["terms"].add(s["slug"].replace("-", " "))
    for a in aliases:
        if a["skill_slug"] in terms_by_slug:
            terms_by_slug[a["skill_slug"]]["terms"].add(a["alias"].lower().strip())

    index = []
    for slug, data in terms_by_slug.items():
        # CNN is also a broadcaster; the bare acronym in employer boilerplate
        # is not evidence of a deep-learning requirement. Match its full name.
        if slug == "deep-learning":
            data["terms"].discard("cnn")
            data["terms"].add("convolutional neural network")
            data["terms"].add("convolutional neural networks")
        patterns = [_compile_term(t) for t in data["terms"] if t]
        index.append({"slug": slug, "name": data["name"], "patterns": patterns})
    return index


def _compile_term(term: str):
    # match `term` when not flanked by other alphanumerics: (?<![a-z0-9])term(?![a-z0-9])
    return re.compile(r"(?<![a-z0-9])" + re.escape(term) + r"(?![a-z0-9])", re.IGNORECASE)


def tag_skills(title: str, body: str, skill_index: list) -> dict:
    """Return {skill_slug: weight(2|3)} for every skill mentioned in the text."""
    title_l = (title or "").lower()
    body_l = (body or "").lower()
    tags = {}
    for skill in skill_index:
        in_title = any(p.search(title_l) for p in skill["patterns"])
        in_body = in_title or any(p.search(body_l) for p in skill["patterns"])
        if in_title:
            tags[skill["slug"]] = TITLE_WEIGHT
        elif in_body:
            tags[skill["slug"]] = BODY_WEIGHT
    return tags


def infer_careers(tagged_skills: dict, career_required: dict, min_score: int = 4,
                  top_n: int = 2, dominance: float = 0.5) -> list:
    """
    Link an opportunity to careers by overlap with each career's answer key.

    tagged_skills   : {skill_slug: weight}   (output of tag_skills)
    career_required : {career_slug: [{"skill_slug","weight"}, ...]}   (the answer key)
    Score per career = sum of the career's own importance-weights for skills that the
    posting actually mentions.

    A career is returned only if it clears two bars, which keeps the links precise
    (a spurious tag is what makes students stop trusting the system):
      * min_score  — an absolute floor, so a couple of generic skills isn't enough;
      * dominance  — it must score at least `dominance`x the top career's score, so a
                     weak secondary match (e.g. "AI Engineer" on a pure frontend role)
                     is dropped rather than listed beside the real one.
    Returns up to `top_n` career slugs, best first (ties broken by slug).
    """
    scores = {}
    for career_slug, reqs in career_required.items():
        score = sum(r["weight"] for r in reqs if r["skill_slug"] in tagged_skills)
        if score >= min_score:
            scores[career_slug] = score
    ranked = sorted(scores.items(), key=lambda kv: (-kv[1], kv[0]))
    if not ranked:
        return []
    cutoff = dominance * ranked[0][1]
    kept = [slug for slug, score in ranked if score >= cutoff]
    return kept[:top_n]
