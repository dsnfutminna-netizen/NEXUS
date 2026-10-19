import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "app"))
sys.path.insert(0, str(ROOT))
import sources
from scripts.sync_cloud_feeds import valid_post


class FeedQualityTests(unittest.TestCase):
    def test_student_terms_require_whole_words_and_exclude_senior_roles(self):
        self.assertTrue(sources.is_student_relevant("Junior Data Analyst", []))
        self.assertFalse(sources.is_student_relevant("International Interpreter", []))
        self.assertFalse(sources.is_student_relevant("Senior Intern Manager", []))

    def test_worker_rejects_unsafe_or_expired_listing(self):
        base = {"external_id": "1", "title": "Junior Data Analyst", "organization": "Example", "url": "https://jobs.example.org/role"}
        self.assertTrue(valid_post(base))
        self.assertFalse(valid_post({**base, "url": "javascript:alert(1)"}))
        self.assertFalse(valid_post({**base, "deadline": "2020-01-01"}))


if __name__ == "__main__":
    unittest.main()
