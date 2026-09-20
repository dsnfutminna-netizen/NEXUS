import type { Dataset, Opportunity } from "./types";
const compare = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0);
export const levels = [
  "Not yet",
  "Beginner",
  "Intermediate",
  "Advanced",
  "Expert",
];
// Python round uses ties-to-even; preserve the pilot's results exactly.
export function roundEven(n: number) {
  const f = Math.floor(n);
  return n - f === 0.5 ? (f % 2 === 0 ? f : f + 1) : Math.round(n);
}
export function gaps(d: Dataset) {
  return d.requirements
    .filter((r) => r.career_id === d.profile.target_career_id)
    .map((r) => {
      const s = d.skills.find((s) => s.id === r.skill_id)!;
      const current = d.ranks[s.slug] || 0;
      const gap = Math.max(r.target_rank - current, 0);
      return {
        ...s,
        current,
        target: r.target_rank,
        weight: r.weight,
        gap,
        priority: gap * r.weight,
      };
    })
    .sort(
      (a, b) =>
        b.priority - a.priority ||
        b.weight - a.weight ||
        compare(a.name, b.name),
    );
}
export function score(d: Dataset, o: Opportunity) {
  const total = o.skills.reduce((n, s) => n + s.weight, 0);
  const matched = o.skills.filter((s) => (d.ranks[s.slug] || 0) >= 1);
  const ratio = total ? matched.reduce((n, s) => n + s.weight, 0) / total : 0;
  const p = d.profile;
  const eligible =
    (o.min_level === null || (p.level !== null && p.level >= o.min_level)) &&
    (o.max_level === null || (p.level !== null && p.level <= o.max_level)) &&
    (!o.departments.length ||
      (p.department_id !== null && o.departments.includes(p.department_id)));
  const career = d.careers.find((c) => c.id === p.target_career_id)?.slug;
  const alignment = !o.careers.length
    ? 0.5
    : o.careers.includes(career || "")
      ? 1
      : 0;
  return {
    coverage: roundEven(ratio * 100),
    score: roundEven(
      100 * (0.65 * ratio + 0.2 * alignment + 0.15 * Number(eligible)),
    ),
    eligible,
    matched: matched.sort(
      (a, b) => b.weight - a.weight || compare(a.name, b.name),
    ),
  };
}
export function completeness(d: Dataset) {
  const p = d.profile;
  return roundEven(
    (100 *
      [
        p.department_id !== null,
        p.level !== null,
        p.cgpa !== null,
        p.target_career_id !== null,
        Object.values(d.ranks).filter((n) => n > 0).length >= 3,
        d.interests.length > 0,
      ].filter(Boolean).length) /
      6,
  );
}
export function safeUrl(value: string | null) {
  try {
    const u = new URL(value || "");
    return ["https:", "http:"].includes(u.protocol) &&
      !u.username &&
      !u.password
      ? u.href
      : null;
  } catch {
    return null;
  }
}
export function sample(o: Opportunity) {
  const host = new URL(safeUrl(o.url) || "https://invalid.local").hostname;
  return (
    o.source === "sample" ||
    ["example.org", "example.com", "example.net"].some(
      (d) => host === d || host.endsWith("." + d),
    )
  );
}
export function expired(o: Opportunity) {
  return (
    !!o.deadline &&
    o.deadline.slice(0, 10) < new Date().toISOString().slice(0, 10)
  );
}
export function earlyCareer(o: Opportunity) {
  return (
    !/\b(senior|sr|lead|head|director|principal|architect)\b/i.test(o.title) &&
    (/\b(junior|intern|internship|graduate|student|entry)\b/i.test(o.title) ||
      [
        "internship",
        "scholarship",
        "fellowship",
        "training",
        "hackathon",
      ].includes(o.category))
  );
}
