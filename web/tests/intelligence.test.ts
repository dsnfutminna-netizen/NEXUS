import { test } from "node:test";
import assert from "node:assert/strict";
import cases from "./parity.json";
import {
  score,
  gaps,
  roundEven,
  safeUrl,
  sample,
  expired,
} from "../src/lib/intelligence";
import type { Dataset, Opportunity } from "../src/lib/types";
for (const [i, fixture] of cases.entries())
  test("Python parity fixture " + i, () => {
    const d = fixture.d as Dataset;
    for (const o of d.opportunities) {
      const expected = fixture.matches.find((m) => m.slug === o.slug)!;
      const actual = score(d, o);
      assert.equal(actual.score, expected.match_score);
      assert.equal(actual.coverage, expected.skill_match_pct);
      assert.equal(actual.eligible, expected.is_eligible);
      assert.deepEqual(
        actual.matched.map((s) => s.name),
        expected.matched_skills,
      );
    }
    assert.deepEqual(
      gaps(d).map((g) => [g.slug, g.gap, g.priority]),
      fixture.gaps.map((g) => [g.skill_slug, g.gap, g.priority]),
    );
  });
test("ties round like Python", () => {
  assert.equal(roundEven(12.5), 12);
  assert.equal(roundEven(13.5), 14);
});
test("unsafe and disguised sample URLs", () => {
  assert.equal(safeUrl("javascript:alert(1)"), null);
  assert.equal(safeUrl("https://user:pass@example.com"), null);
  assert.equal(
    sample({
      source: "live",
      url: "https://example.org.evil.test",
    } as Opportunity),
    false,
  );
  assert.equal(
    sample({ source: "live", url: "https://jobs.example.org" } as Opportunity),
    true,
  );
});
test("expired postings", () =>
  assert.equal(expired({ deadline: "2000-01-01" } as Opportunity), true));
