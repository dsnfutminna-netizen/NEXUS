"""Supabase adapter. One client per Streamlit session; user JWTs enforce RLS.

No service-role key and no global client/cache are used by the student app.
"""
from datetime import datetime, timezone


class CloudDatabase:
    def __init__(self, client):
        self.client = client

    def rows(self, table, columns="*", **filters):
        result = []
        start = 0
        while True:
            request = self.client.table(table).select(columns)
            keys = {"proficiency_levels": ["rank"], "skill_aliases": ["skill_id", "alias"],
                    "career_required_skills": ["career_id", "skill_id"],
                    "student_skills": ["student_id", "skill_id"],
                    "student_interests": ["student_id", "industry_id"],
                    "saved_opportunities": ["student_id", "opportunity_id"],
                    "opportunity_skills": ["opportunity_id", "skill_id"],
                    "opportunity_careers": ["opportunity_id", "career_id"],
                    "opportunity_departments": ["opportunity_id", "department_id"]}
            for key in keys.get(table, ["id"]):
                request = request.order(key)
            for column, value in filters.items():
                request = request.eq(column, value)
            batch = request.range(start, start + 499).execute().data
            result.extend(batch)
            if len(batch) < 500:
                return result
            start += 500

    def authenticate(self, email, password):
        self.client.auth.sign_in_with_password({"email": email.strip().lower(), "password": password})
        return self.ensure_profile()

    def create_user(self, name, email, password, redirect=None):
        options = {"data": {"full_name": name.strip()}}
        if redirect:
            options["email_redirect_to"] = redirect
        response = self.client.auth.sign_up({"email": email.strip().lower(), "password": password, "options": options})
        if not response.session:
            return None
        return self.ensure_profile()["id"]

    def ensure_profile(self):
        # get_user validates with Auth; do not authorize using mutable metadata.
        user = self.client.auth.get_user().user
        found = self.rows("profiles", id=user.id)
        if not found:
            try:
                self.client.table("profiles").insert({"id": user.id, "email": user.email,
                    "full_name": (user.user_metadata or {}).get("full_name") or "Student"}).execute()
            except Exception:
                # A concurrent sign-in may have created the same profile.
                if not self.rows("profiles", id=user.id):
                    raise
        return self.get_profile(user.id)

    def sign_out(self):
        self.client.auth.sign_out({"scope": "local"})

    def get_profile(self, uid):
        found = self.rows("profiles", id=uid)
        if not found:
            raise ValueError("Your profile is unavailable. Please sign in again.")
        return found[0]

    def get_careers(self):
        return sorted(self.rows("careers", is_active=True), key=lambda r: r["name"])

    def get_departments(self):
        return sorted(self.rows("departments"), key=lambda r: r["name"])

    def get_industries(self):
        return sorted(self.rows("industries"), key=lambda r: r["name"])

    def get_skills_by_category(self):
        cats = {c["id"]: c["name"] for c in self.rows("skill_categories")}
        groups = {}
        for skill in sorted(self.rows("skills", is_active=True), key=lambda r: (cats[r["category_id"]], r["name"])):
            groups.setdefault(cats[skill["category_id"]], []).append(skill)
        return groups

    def get_career_required(self, career_id):
        if career_id is None:
            return []
        skills = {s["id"]: s for s in self.rows("skills")}
        return [{"skill_slug": skills[r["skill_id"]]["slug"], "skill_name": skills[r["skill_id"]]["name"],
                 "target_rank": r["target_rank"], "weight": r["weight"]}
                for r in self.rows("career_required_skills", career_id=career_id)]

    def get_target_career_slug(self, uid):
        target = self.get_profile(uid)["target_career_id"]
        return next((c["slug"] for c in self.get_careers() if c["id"] == target), None)

    def update_academic(self, uid, department_id, level, cgpa, target_career_id, consent):
        payload = dict(department_id=department_id, level=level, cgpa=cgpa,
                       target_career_id=target_career_id, data_consent=bool(consent),
                       consent_at=datetime.now(timezone.utc).isoformat() if consent else None,
                       consent_version="pilot-1")
        self.client.table("profiles").update(payload).eq("id", uid).execute()

    def get_student_skill_ranks_by_id(self, uid):
        return {r["skill_id"]: r["proficiency_rank"] for r in self.rows("student_skills", student_id=uid)}

    def get_student_skill_ranks_by_slug(self, uid):
        skills = {s["id"]: s["slug"] for s in self.rows("skills")}
        return {skills[r["skill_id"]]: r["proficiency_rank"] for r in self.rows("student_skills", student_id=uid)}

    def count_student_skills(self, uid):
        return len(self.rows("student_skills", student_id=uid))

    def set_student_skills(self, uid, ranks):
        # Atomic RPC derives identity from auth.uid(), not a caller-supplied ID.
        self.client.rpc("save_my_skills", {"ratings": [{"skill_id": key, "rank": value} for key, value in ranks.items()]}).execute()

    def get_interest_ids(self, uid):
        return [r["industry_id"] for r in self.rows("student_interests", student_id=uid)]

    def set_interests(self, uid, ids):
        self.client.rpc("save_my_interests", {"industry_ids": ids}).execute()

    def get_saved_ids(self, uid):
        return {r["opportunity_id"] for r in self.rows("saved_opportunities", student_id=uid)}

    def toggle_saved(self, uid, oid):
        if oid in self.get_saved_ids(uid):
            self.client.table("saved_opportunities").delete().eq("student_id", uid).eq("opportunity_id", oid).execute()
            return False
        self.client.table("saved_opportunities").upsert({"student_id": uid, "opportunity_id": oid}, on_conflict="student_id,opportunity_id").execute()
        return True

    def get_opportunities_for_matching(self):
        import tagger
        opps = {o["id"]: dict(o, skills=[], careers=set(), departments=set()) for o in self.rows("opportunities", is_active=True)}
        skills = {s["id"]: s for s in self.rows("skills")}
        careers = {c["id"]: c for c in self.get_careers()}
        for row in self.rows("opportunity_skills"):
            if row["opportunity_id"] in opps:
                skill = skills[row["skill_id"]]
                opps[row["opportunity_id"]]["skills"].append({"slug": skill["slug"], "name": skill["name"], "weight": row["weight"]})
        for row in self.rows("opportunity_careers"):
            if row["opportunity_id"] in opps and row["career_id"] in careers:
                opps[row["opportunity_id"]]["careers"].add(careers[row["career_id"]]["slug"])
        for row in self.rows("opportunity_departments"):
            if row["opportunity_id"] in opps:
                opps[row["opportunity_id"]]["departments"].add(row["department_id"])
        aliases = [{"skill_slug": skills[a["skill_id"]]["slug"], "alias": a["alias"]} for a in self.rows("skill_aliases")]
        index = tagger.build_skill_index(list(skills.values()), aliases)
        required = {}
        for row in self.rows("career_required_skills"):
            if row["career_id"] in careers:
                required.setdefault(careers[row["career_id"]]["slug"], []).append({"skill_slug": skills[row["skill_id"]]["slug"], "weight": row["weight"]})
        names = {s["slug"]: s["name"] for s in skills.values()}
        for opp in opps.values():
            if opp.get("source") in {"remotive", "remoteok"}:
                tags = tagger.tag_skills(opp["title"], opp.get("description"), index)
                opp["skills"] = [{"slug": slug, "name": names[slug], "weight": weight} for slug, weight in tags.items()]
                opp["careers"] = set(tagger.infer_careers(tags, required))
        return list(opps.values())

    def log_event(self, uid, event_type, entity_type=None, entity_id=None, metadata=None):
        self.client.table("events").insert({"student_id": uid, "event_type": event_type, "entity_type": entity_type,
            "entity_id": str(entity_id) if entity_id is not None else None, "metadata": metadata or {}}).execute()

    def save_feedback(self, uid, before, after, nps, comment):
        self.client.table("feedback").insert({"student_id": uid, "clarity_before": before,
            "clarity_after": after, "nps": nps, "comment": comment}).execute()
