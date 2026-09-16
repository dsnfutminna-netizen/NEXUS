"""Isolated pilot regression checks. Run: python app/tests/test_pilot_ui.py"""
import os
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP))
_temp = tempfile.TemporaryDirectory()
os.environ["NEXUS_DB_PATH"] = str(Path(_temp.name) / "test.db")
os.environ["NEXUS_BACKEND"] = "sqlite"
import db
import seed_db
import presentation as ui
import tagger
from streamlit.testing.v1 import AppTest


class PilotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        seed_db.main(with_demo=True)
        cls.uid = db.create_user("Pilot Tester", "pilot@example.test", "test-password")
        with closing(db.get_conn()) as conn:
            conn.execute("UPDATE profiles SET data_consent=1 WHERE id=?", (cls.uid,))
            conn.commit()

    def app(self, page="Profile"):
        at = AppTest.from_file(str(APP / "app.py"), default_timeout=20)
        at.session_state["uid"] = self.uid
        at.session_state["uname"] = "Pilot Tester"
        at.session_state["page"] = page
        at.run()
        self.assertFalse(at.exception)
        return at

    def test_feedback_requires_deliberate_answers_and_saves_once(self):
        at = self.app("Feedback")
        ratings = [s for s in at.selectbox if s.label != "Navigate"]
        self.assertTrue(all(s.value is None for s in ratings))
        next(b for b in at.button if b.label == "Submit feedback").click().run()
        self.assertTrue(at.error)
        self.assertEqual(db.query("SELECT count(*) n FROM feedback", one=True)["n"], 0)
        ratings = [s for s in at.selectbox if s.label != "Navigate"]
        for widget, value in zip(ratings, [2, 2, 0]):
            widget.set_value(value)
        next(b for b in at.button if b.label == "Submit feedback").click().run()
        self.assertFalse(at.exception)
        row = db.query("SELECT * FROM feedback", one=True)
        self.assertEqual((row["clarity_before"], row["clarity_after"], row["nps"]), (2, 2, 0))
        at.run()
        self.assertEqual(db.query("SELECT count(*) n FROM feedback", one=True)["n"], 1)

    def test_withdrawing_consent_pauses_personalization_and_analytics(self):
        with closing(db.get_conn()) as conn:
            conn.execute("UPDATE profiles SET data_consent=0 WHERE id=?", (self.uid,))
            conn.commit()
        before = db.query("SELECT count(*) n FROM events", one=True)["n"]
        try:
            for page in ["Skill gaps", "Opportunities"]:
                at = self.app(page)
                self.assertTrue(any("Personalized results are paused" in msg.value for msg in at.info))
                self.assertFalse(at.get("link_button"))
            self.assertEqual(db.query("SELECT count(*) n FROM events", one=True)["n"], before)
        finally:
            with closing(db.get_conn()) as conn:
                conn.execute("UPDATE profiles SET data_consent=1 WHERE id=?", (self.uid,))
                conn.commit()

    def test_sample_links_disabled_and_saved_filter(self):
        at = self.app("Opportunities")
        self.assertFalse(at.get("link_button"))
        at.radio[0].set_value("Sample listings").run()
        self.assertFalse(at.exception)
        self.assertFalse(at.get("link_button"))
        save = next(b for b in at.button if b.label == "Save opportunity")
        save.click().run()
        self.assertTrue(db.get_saved_ids(self.uid))
        next(c for c in at.checkbox if c.label == "Saved only").check().run()
        self.assertEqual(len([b for b in at.button if b.label == "Remove from saved"]), 1)
        next(b for b in at.button if b.label == "Remove from saved").click().run()
        self.assertFalse(db.get_saved_ids(self.uid))

    def test_profile_save_and_completed_skills_action(self):
        at = self.app()
        next(b for b in at.button if b.label == "Save academic details").click().run()
        self.assertFalse(at.exception)
        self.assertTrue(at.success)
        profile = db.get_profile(self.uid)
        required = db.get_career_required(profile["target_career_id"])
        ids = {r["slug"]: r["id"] for r in db.query("SELECT id,slug FROM skills")}
        db.set_student_skills(self.uid, {ids[r["skill_slug"]]: r["target_rank"] for r in required})
        at = self.app("Skill gaps")
        self.assertTrue(any("meet every target" in msg.value for msg in at.success))
        next(b for b in at.button if b.label == "Explore opportunities").click().run()
        self.assertEqual(at.selectbox(key="page").value, "Opportunities")
        self.assertFalse(at.exception)

    def test_sample_detection_safe_links_and_seniority(self):
        self.assertTrue(ui.is_sample({"url": "https://example.org/job"}))
        self.assertTrue(ui.is_sample({"url": "https://jobs.example.com/job"}))
        self.assertFalse(ui.is_sample({"url": "https://example.org.evil.test/job"}))
        self.assertIsNone(ui.safe_url("javascript:alert(1)"))
        self.assertEqual(ui.seniority({"title": "Senior AI Architect"}), "Experienced roles")
        self.assertTrue(ui.expired({"deadline": "2000-01-01"}))

    def test_filters_combine_and_hide_expired(self):
        opps = [{"slug": "a", "id": 1, "title": "Junior AI Engineer", "category": "job", "source": "live", "url": "https://jobs.test/a", "careers": {"ai-engineer"}},
                {"slug": "b", "id": 2, "title": "Senior AI Engineer", "category": "job", "source": "live", "url": "https://jobs.test/b", "careers": {"ai-engineer"}},
                {"slug": "c", "id": 3, "title": "Junior AI Engineer", "deadline": "2000-01-01", "url": "https://jobs.test/c"}]
        matches = [dict(o, skill_match_pct=100) for o in opps]
        result = ui.filter_matches(matches, {o["slug"]: o for o in opps}, query="AI", experience="Student / early career", career_only=True, career="ai-engineer", saved_only=True, saved={1, 2})
        self.assertEqual([m["slug"] for m in result], ["a"])

    def test_broadcaster_is_not_deep_learning(self):
        index = tagger.build_skill_index([{"slug": "deep-learning", "name": "Deep Learning"}], [{"skill_slug": "deep-learning", "alias": "cnn"}])
        self.assertEqual(tagger.tag_skills("Customer Support", "Our clients include NASA, CNN and the NHS.", index), {})
        self.assertIn("deep-learning", tagger.tag_skills("Engineer", "Build convolutional neural networks", index))

    def test_new_account_validation_and_login(self):
        at = AppTest.from_file(str(APP / "app.py"), default_timeout=20).run()
        fields = {t.label: t for t in at.text_input}
        fields["Full name"].set_value("Test signup")
        fields["Email "].set_value("invalid")
        fields["Password "].set_value("test-password")
        next(b for b in at.button if b.label == "Create account").click().run()
        self.assertTrue(at.error)
        self.assertIsNone(db.query("SELECT id FROM profiles WHERE email='invalid'", one=True))
        next(t for t in at.text_input if t.label == "Email ").set_value("signup@example.test")
        next(b for b in at.button if b.label == "Create account").click().run()
        self.assertFalse(at.exception)
        self.assertEqual(at.selectbox(key="page").value, "Profile")
        next(b for b in at.button if b.label == "Log out").click().run()
        self.assertFalse(at.exception)
        next(t for t in at.text_input if t.label == "Email").set_value("signup@example.test")
        next(t for t in at.text_input if t.label == "Password").set_value("test-password")
        next(b for b in at.button if b.label == "Log in").click().run()
        self.assertFalse(at.exception)
        self.assertEqual(at.selectbox(key="page").value, "Profile")


if __name__ == "__main__":
    try:
        unittest.main()
    finally:
        _temp.cleanup()
