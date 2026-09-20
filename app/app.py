"""
NEXUS — pilot Streamlit app (the golden path).

    signup / login  ->  build profile  ->  see skill gaps  ->  ranked
    opportunity matches  ->  next actions  ->  feedback

Everything intelligent (gaps, match scores, recommendations) is computed by
app/intelligence.py — the same rules as the production SQL views — so what you
see on stage is exactly what the database will compute in Supabase later.

Run:  streamlit run app/app.py     (the DB self-creates on first launch)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from html import escape
import re
import os
import presentation as ui
from auth_messages import auth_error_message
import streamlit as st

import db as sqlite_db
import intelligence as ai
import ingest
import sources
import seed_db

st.set_page_config(page_title="NEXUS", page_icon="N", layout="wide")

st.markdown("<style>" + Path(__file__).with_name("styles.css").read_text() + "</style>", unsafe_allow_html=True)


def setting(name, default=""):
    if name in os.environ:
        return os.environ[name]
    try:
        return st.secrets.get(name, default)
    except FileNotFoundError:
        return default


CLOUD = setting("NEXUS_BACKEND", "sqlite") == "supabase"
db = sqlite_db
if CLOUD:
    from cloud_db import CloudDatabase
    from supabase import create_client, ClientOptions
    url, key = setting("SUPABASE_URL"), setting("SUPABASE_PUBLISHABLE_KEY")
    if not url or not key or key.startswith("sb_secret_"):
        st.error("NEXUS is not configured yet. Please contact the pilot team.")
        st.stop()
    if not key.startswith("sb_publishable_"):
        import base64
        import json
        try:
            payload = key.split(".")[1]
            if json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))["role"] != "anon":
                raise ValueError("Not a public key")
        except (ValueError, KeyError, IndexError):
            st.error("NEXUS requires a publishable key. Contact the pilot team.")
            st.stop()
    if "supabase_client" not in st.session_state:
        st.session_state.supabase_client = create_client(url, key, options=ClientOptions(persist_session=True, auto_refresh_token=True))
    db = CloudDatabase(st.session_state.supabase_client)

# Zero-setup: build + seed the DB the first time the app runs.
if not CLOUD and not db.DB_PATH.exists():
    seed_db.main(with_demo=True)

LEVELS = [100, 200, 300, 400, 500, 600, 700]
PROF_OPTS = [0, 1, 2, 3, 4]  # None..Expert


# ------------------------------------------------------------------- helpers
def record_event(uid, event_type, entity_type=None, entity_id=None, metadata=None):
    # Optional analytics must not interrupt core actions or ignore consent.
    try:
        if db.get_profile(uid)["data_consent"]:
            db.log_event(uid, event_type, entity_type, entity_id, metadata)
    except Exception:
        pass


def current_user():
    return st.session_state.get("uid")


def logout():
    if CLOUD:
        try:
            db.sign_out()
        except Exception:
            # Always clear this browser session, including the client/token.
            pass
    for k in list(st.session_state):
        del st.session_state[k]
    st.rerun()


def navigate(page):
    st.session_state.page = page


def notice(message):
    st.session_state.notice = message
    st.rerun()


def go_button(label, page, key=None):
    st.button(label, on_click=navigate, args=(page,), key=key, type="primary")


# Friendly names for where an opportunity came from (source column).
# "seed" = the hand-curated DSN/FUTMinna items loaded from CSV.
SOURCE_LABELS = {"seed": "Curated", "sample": "Sample feed",
                 "remotive": "Remotive", "remoteok": "RemoteOK"}


def source_label(source: str) -> str:
    if not source:
        return "Curated"
    return SOURCE_LABELS.get(source, source.title())


# --------------------------------------------------------------------- auth
def render_auth():
    st.title("NEXUS")
    st.markdown("<div class=auth-marker></div>", unsafe_allow_html=True)
    st.write("Find the skills to build and opportunities that fit your career goal.")
    st.caption("DSN FUTMinna · Student pilot")
    if CLOUD:
        st.caption("First time on this site? Create a new account. Accounts from the local demo are separate.")
    login_tab, signup_tab = st.tabs(["Log in", "Create account"])

    with login_tab:
        with st.form("login"):
            email = st.text_input("Email")
            pw = st.text_input("Password", type="password")
            if st.form_submit_button("Log in", use_container_width=True, type="primary"):
                try:
                    row = db.authenticate(email, pw)
                except Exception as error:
                    st.error(auth_error_message(error, "login"))
                    row = None
                    return
                if row:
                    st.session_state.uid = row["id"]
                    st.session_state.uname = row["full_name"]
                    record_event(row["id"], "login")
                    st.rerun()
                else:
                    st.error("Sign-in failed. Check your email and password, confirm your email if needed, or try again shortly.")
        with st.expander("Need help signing in?"):
            st.write("Check your email spelling and password. Password reset is not available in this pilot. Ask the DSN FUTMinna facilitator who invited you for account help; never share your password.")
            support = ui.safe_url(setting("NEXUS_SUPPORT_URL"))
            if support:
                st.link_button("Contact pilot support", support)
        if setting("NEXUS_SHOW_DEMO") == "1":
            st.info("Demo login — **demo@nexus.test** / **demo1234**")

    with signup_tab:
        with st.form("signup"):
            name = st.text_input("Full name")
            email = st.text_input("Email ")
            pw = st.text_input("Password ", type="password", help="Use at least 6 characters. Do not reuse an important password.")
            st.caption("Password: at least 6 characters.")
            if st.form_submit_button("Create account", use_container_width=True, type="primary"):
                if not (name.strip() and re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email.strip()) and len(pw) >= 6):
                    st.error("Enter your name, a valid email, and a password of at least 6 characters.")
                else:
                    try:
                        uid = db.create_user(name, email, pw, redirect=ui.safe_url(setting("NEXUS_APP_URL"))) if CLOUD else db.create_user(name, email, pw)
                        if uid is None:
                            st.success("Check your email to confirm your account, then return here to log in.")
                            return
                        st.session_state.uid = uid
                        st.session_state.uname = name
                        record_event(uid, "signup")
                        st.rerun()
                    except Exception as error:
                        st.error(auth_error_message(error, "signup"))


# ------------------------------------------------------------------ profile
def page_profile(uid):
    st.header("Your profile")
    profile = db.get_profile(uid)
    careers = db.get_careers()
    departments = db.get_departments()
    industries = db.get_industries()

    # ---- completeness banner
    sections = {
        "department": profile["department_id"] is not None,
        "level": profile["level"] is not None,
        "cgpa": profile["cgpa"] is not None,
        "target_career": profile["target_career_id"] is not None,
        "has_3_skills": db.count_student_skills(uid) >= 3,
        "has_interest": len(db.get_interest_ids(uid)) >= 1,
    }
    pct = ai.profile_completeness(sections)
    st.progress(pct / 100, text=f"Profile {pct}% complete")
    if pct < 100:
        missing = [k.replace("_", " ") for k, v in sections.items() if not v]
        st.caption("Add: " + ", ".join({"has 3 skills":"at least 3 skills", "has interest":"an industry interest"}.get(m,m) for m in missing))
    else:
        go_button("View my skill gaps", "Skill gaps")

    # ---- academic form
    st.subheader("Academic")
    with st.form("academic"):
        dept_ids = [d["id"] for d in departments]
        dept_idx = dept_ids.index(profile["department_id"]) if profile["department_id"] in dept_ids else 0
        dept = st.selectbox("Department", departments, index=dept_idx,
                            format_func=lambda d: f"{d['name']} ({d['faculty']})")

        lvl_idx = LEVELS.index(profile["level"]) if profile["level"] in LEVELS else 2
        level = st.selectbox("Level", LEVELS, index=lvl_idx)

        cgpa = st.number_input("CGPA (0.0 – 5.0)", 0.0, 5.0,
                               float(profile["cgpa"]) if profile["cgpa"] is not None else 3.50,
                               step=0.01)

        car_ids = [c["id"] for c in careers]
        car_idx = car_ids.index(profile["target_career_id"]) if profile["target_career_id"] in car_ids else 0
        career = st.selectbox("Target career", careers, index=car_idx,
                              format_func=lambda c: c["name"])

        consent = st.checkbox("I agree to use my profile for personalized recommendations and pilot usage analytics.",
                              value=bool(profile["data_consent"]))
        st.caption("You can withdraw this choice here. This pauses personalization and new usage analytics; it does not delete your saved profile or feedback. Contact the pilot facilitator to request deletion.")
        if st.form_submit_button("Save academic details"):
            db.update_academic(uid, dept["id"], level, cgpa, career["id"], consent)
            record_event(uid, "update_profile", "academic")
            notice("Academic details saved. Recommendations are enabled." if consent else "Academic details saved. Personalization and usage analytics are paused.")

    # ---- skills
    st.subheader("Skills")
    st.write("Rate what you can do today. You can update this as you learn.")
    with st.expander("How to choose a skill level"):
        st.markdown("**None:** Not tried yet.\n\n**Beginner:** Follow a guided example.\n\n**Intermediate:** Complete a familiar task with occasional help.\n\n**Advanced:** Deliver a project independently and explain your choices.\n\n**Expert:** Handle unfamiliar problems, review others’ work, and teach the skill.")
    current = db.get_student_skill_ranks_by_id(uid)
    by_cat = db.get_skills_by_category()
    required_slugs = {r["skill_slug"] for r in db.get_career_required(profile["target_career_id"])}
    all_skills = [skill for group in by_cat.values() for skill in group]
    groups = {}
    if required_slugs:
        groups["For your target career"] = [skill for skill in all_skills if skill["slug"] in required_slugs]
    for category, skills in by_cat.items():
        remaining = [skill for skill in skills if skill["slug"] not in required_slugs]
        if remaining:
            groups[category] = remaining
    with st.form("skills"):
        chosen = {}
        for category, skills in groups.items():
            rated = sum(current.get(skill["id"], 0) > 0 for skill in skills)
            with st.expander(f"{category} · {rated}/{len(skills)} rated", expanded=category == "For your target career"):
                st.caption("Rated counts reflect your last save. Save skills below to apply changes.")
                for s in skills:
                    chosen[s["id"]] = st.selectbox(
                        s["name"], PROF_OPTS,
                        index=current.get(s["id"], 0),
                        format_func=lambda r: ai.PROFICIENCY[r],
                        key=f"sk_{s['id']}")
        if st.form_submit_button("Save skills"):
            db.set_student_skills(uid, chosen)
            record_event(uid, "update_profile", "skills")
            notice("Skills saved. View Skill gaps to choose your next step.")

    # ---- interests
    st.subheader("Industry interests")
    with st.form("interests"):
        current_ints = set(db.get_interest_ids(uid))
        picked = st.multiselect("Industries you'd like to work in", industries,
                                default=[i for i in industries if i["id"] in current_ints],
                                format_func=lambda i: i["name"])
        if st.form_submit_button("Save interests"):
            db.set_interests(uid, [i["id"] for i in picked])
            record_event(uid, "update_profile", "interests")
            notice("Industry interests saved.")


# --------------------------------------------------------------- skill gaps
def page_gaps(uid):
    st.header("Skill-gap analysis")
    profile = db.get_profile(uid)
    if not profile["target_career_id"]:
        st.warning("Pick a **target career** on your profile first — that's the yardstick we measure against.")
        go_button("Choose my target career", "Profile", "choose_career")
        return

    record_event(uid, "view_gaps", "career", profile["target_career_id"])
    career_slug = db.get_target_career_slug(uid)
    career = next(c for c in db.get_careers() if c["id"] == profile["target_career_id"])
    required = db.get_career_required(profile["target_career_id"])
    student = db.get_student_skill_ranks_by_slug(uid)
    gaps = ai.compute_skill_gaps(student, required)

    st.subheader(f"Target: {career['name']}")
    on_track = sum(1 for g in gaps if g["gap"] == 0)
    remaining = len(gaps) - on_track
    st.write(f"**{on_track} of {len(gaps)} skills on track** · {remaining} to develop")
    recs = ai.recommend_next_actions(gaps, top_n=3)
    if recs:
        st.subheader("Your next step")
        st.write(f"**{recs[0]['title']}**")
        st.write(recs[0]["detail"])
        with st.expander("Then work on these"):
            for rec in recs[1:]:
                st.write(f"**{rec['title']}**")
                st.write(rec["detail"])
    elif gaps:
        st.success("Your self-rated skills meet every target level.")
        st.write("Put them to work: explore opportunities or build a project that demonstrates your skills. Self-ratings are a starting point, not a certification.")
    else:
        st.info("This career does not have a skill checklist yet. Explore opportunities while the pilot team prepares it.")
    go_button("Explore opportunities", "Opportunities")
    st.subheader("Your skill checklist")
    for gap in gaps:
        status = "On track" if not gap["gap"] else f"{gap['gap_label']} priority"
        st.markdown(f"<div class='skill-row'><strong>{escape(gap['skill_name'])}</strong>"
                    f"You: {escape(gap['current_label'])} → Target: {escape(gap['target_label'])}"
                    f"<br><small>{status}</small></div>", unsafe_allow_html=True)
    go_button("Update my skill ratings", "Profile", "update_ratings")


# ------------------------------------------------------------- opportunities
def page_opportunities(uid):
    st.header("Find opportunities")
    profile = db.get_profile(uid)
    student = {"level": profile["level"], "department_id": profile["department_id"],
               "target_career_slug": db.get_target_career_slug(uid)}
    skills = db.get_student_skill_ranks_by_slug(uid)
    opps = db.get_opportunities_for_matching()
    by_slug = {opp["slug"]: opp for opp in opps}
    matches = ai.compute_matches(student, skills, opps)
    saved = db.get_saved_ids(uid)
    if not skills:
        st.info("Add your skills to get a useful comparison. You can still browse listings below.")
        go_button("Add my skills", "Profile", "opps_profile")
    st.write("Compare skills, check requirements, and save opportunities to revisit.")
    st.caption("Skills coverage counts tagged skills you rated Beginner or above, weighted by the posting’s tags. It does not measure proficiency or your chance of being accepted.")
    mode = st.radio("Listings", ["Live listings", "Sample listings"], horizontal=True)
    sample = mode == "Sample listings"
    if sample:
        st.info("Demonstration content only. These listings cannot be used to apply.")
    else:
        live = [o for o in opps if not ui.is_sample(o) and not ui.expired(o)]
        fetched = max((o.get("fetched_at") or "" for o in live), default="")
        st.caption(f"{len(live)} current listings in this pilot" + (f" · Last fetched {fetched} UTC" if fetched else ""))
        st.caption("A listing may change after it is fetched. Confirm availability on the source website.")
    search = st.text_input("Search title or organization", key="opp_search")
    with st.expander("Filter and sort", expanded=False):
        category = st.selectbox("Opportunity type", ["All"] + sorted({o["category"] for o in opps if o.get("category")}), format_func=str.title)
        experience = st.selectbox("Experience", ["All", "Student / early career", "Experienced roles", "Not stated in title"])
        source = st.selectbox("Source", ["All"] + sorted({o.get("source") or "seed" for o in opps}), format_func=lambda x: x if x == "All" else source_label(x))
        career_only = st.checkbox("Only listings tagged for my target career", help="Career tags are inferred from skills and may be inaccurate.")
        sort = st.selectbox("Sort by", ["Skills coverage", "Deadline soonest"])
    saved_only = st.checkbox("Saved only")
    filtered = ui.filter_matches(matches, by_slug, sample=sample, query=search,
        category=category, source=source, experience=experience, career_only=career_only,
        career=student["target_career_slug"], saved_only=saved_only, saved=saved, sort=sort)
    signature = (mode, search, category, experience, source, career_only, saved_only, sort)
    if st.session_state.get("filter_signature") != signature:
        st.session_state.filter_signature = signature
        st.session_state.opp_limit = 10
    st.caption(f"{len(filtered)} results")
    if not filtered:
        st.info("No listings match this view. Try a broader search, change filters, or turn off Saved only.")
    limit = st.session_state.get("opp_limit", 10)
    for match in filtered[:limit]:
        opp = by_slug[match["slug"]]
        oid = opp["id"]
        st.subheader(match["title"])
        place = opp.get("location") or ("Remote" if opp.get("is_remote") else "Location not stated")
        st.caption(" · ".join(str(x) for x in [opp.get("organization"), (opp.get("category") or "").title(), place, source_label(opp.get("source"))] if x))
        st.write(f"**{match['skill_match_pct']}% tagged skills coverage** · {len(match['matched_skills'])}/{len(opp['skills'])} tagged skills")
        st.caption(ui.seniority(opp) + " · inferred from title/type; verify in posting")
        if not match["is_eligible"]:
            st.error("Your profile does not meet the recorded level or department limits.")
        with st.expander("Skills and requirements to check"):
            st.write("**Skills you have:** " + (", ".join(match["matched_skills"]) or "No overlap yet"))
            missing = [s["name"] for s in opp["skills"] if skills.get(s["slug"], 0) < 1]
            st.write("**Not rated yet:** " + (", ".join(missing) or "You have rated all tagged skills."))
            linked = student["target_career_slug"] in opp.get("careers", set())
            st.write("**Career tag:** " + ("Includes your target career." if linked else "No tag for your target career."))
            st.caption("Tags are extracted from text, not verified requirements. Check years of experience, location restrictions, work authorization, proficiency, and deadlines in the original posting. Remote does not always mean worldwide.")
            st.write("**Recorded deadline:** " + (str(opp.get("deadline")) if opp.get("deadline") else "Not stated"))
            st.write("**Academic limits:** " + (f"Level {opp.get('min_level') or 'any'} to {opp.get('max_level') or 'any'}; " + ("department restrictions recorded" if opp.get("departments") else "no department restriction recorded")))
        if sample:
            st.caption("Sample listing · applications disabled")
        elif ui.safe_url(opp.get("url")):
            st.link_button("Read requirements and apply", ui.safe_url(opp["url"]))
        else:
            st.caption("Application link unavailable. Contact the pilot facilitator.")
        if st.button("Remove from saved" if oid in saved else "Save opportunity", key=f"save_{oid}"):
            now_saved = db.toggle_saved(uid, oid)
            notice("Opportunity saved. Use Saved only to find it again." if now_saved else "Opportunity removed from saved.")
        st.divider()
    if len(filtered) > limit and st.button("Show 10 more"):
        st.session_state.opp_limit = limit + 10
        st.rerun()
    if CLOUD:
        st.caption("The pilot team refreshes listings centrally. Use the source website to confirm availability.")
        return
    with st.expander("Update listings"):
        st.caption("Fetch current postings from connected sources. Existing listings remain available if a source fails.")
        if st.button("Refresh listings"):
            with st.spinner("Fetching opportunities…"):
                totals = ingest.run_ingest(adapters=[sources.RemotiveAdapter, sources.RemoteOKAdapter], verbose=False)
            if not totals["fetched"]:
                st.error("No postings were fetched. Try again later; existing listings are still available.")
            else:
                notice(f"Refresh finished: {totals['inserted']} new and {totals['updated']} updated. Some sources may be unavailable; check listing dates.")


# ----------------------------------------------------------------- feedback
def page_feedback(uid):
    st.header("Help improve NEXUS")
    st.write("What worked, and what got in your way? Honest feedback helps us decide what to improve.")
    if st.session_state.get("feedback_sent"):
        st.success("Your feedback was saved. Thank you for testing NEXUS.")
        go_button("Back to opportunities", "Opportunities", "feedback_done")
        return
    with st.form("feedback"):
        st.caption("Clarity: 1 = not clear at all; 5 = very clear.")
        before = st.selectbox("Before using NEXUS, how clear was your career path?", range(1, 6), index=None, placeholder="Choose a rating")
        after = st.selectbox("After using NEXUS, how clear is it now?", range(1, 6), index=None, placeholder="Choose a rating")
        st.caption("Recommendation: 0 = not at all likely; 10 = extremely likely.")
        nps = st.selectbox("How likely are you to recommend NEXUS to a coursemate?", range(11), index=None, placeholder="Choose a rating")
        comment = st.text_area("What helped, what was confusing, or what is missing? (optional)")
        if st.form_submit_button("Submit feedback", type="primary"):
            if any(value is None for value in (before, after, nps)):
                st.error("Choose all three ratings before submitting. Your written feedback is optional.")
            else:
                db.save_feedback(uid, before, after, nps, comment.strip() or None)
                record_event(uid, "submit_feedback", metadata={"delta": after - before, "nps": nps})
                st.session_state.feedback_sent = True
                st.rerun()


# --------------------------------------------------------------------- shell
def main():
    if not current_user():
        render_auth()
        return

    uid = current_user()
    st.markdown("<div class='brand'>NEXUS<span> / </span>YOUR NEXT STEP</div>", unsafe_allow_html=True)
    st.caption(f"Signed in as {st.session_state.uname}")
    if message := st.session_state.pop("notice", None):
        st.success(message)
    page = st.selectbox("Navigate", ["Profile", "Skill gaps", "Opportunities", "Feedback"], key="page")
    if page in {"Skill gaps", "Opportunities"} and not db.get_profile(uid)["data_consent"]:
        st.info("Personalized results are paused. You can enable recommendations in your Academic profile, or continue editing your profile and giving feedback.")
        go_button("Review my consent", "Profile")
    else:
        {"Profile": page_profile, "Skill gaps": page_gaps,
         "Opportunities": page_opportunities, "Feedback": page_feedback}[page](uid)
    st.divider()
    st.caption("NEXUS · DSN FUTMinna pilot")
    if st.button("Log out"):
        logout()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        if not CLOUD:
            raise
        st.error("We couldn't load or save this information. Please check your changes after retrying, or sign out and sign in if your session expired.")
        if st.button("Sign out and retry"):
            logout()
