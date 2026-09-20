import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { supabase } from "./supabase";
import type { Dataset, Profile, Opportunity } from "./types";
export const session = cache(async () => {
  const db = await supabase();
  const { data, error } = await db.auth.getUser();
  if (error || !data.user) redirect("/login");
  const result = await db
    .from("profiles")
    .select("*")
    .eq("id", data.user.id)
    .single();
  if (result.error) redirect("/auth/complete");
  return { db, user: data.user, profile: result.data as Profile };
});
export const dataset = cache(async (): Promise<Dataset> => {
  const { db, profile } = await session();
  async function all(table: string, order = "id") {
    const rows: Record<string, unknown>[] = [];
    for (let start = 0; ; start += 500) {
      const extra: Record<string, string[]> = {
        career_required_skills: ["career_id"],
        student_skills: ["student_id"],
        student_interests: ["student_id"],
        opportunity_skills: ["opportunity_id"],
        opportunity_careers: ["opportunity_id"],
        opportunity_departments: ["opportunity_id"],
        saved_opportunities: ["student_id"],
      };
      let query = db.from(table).select("*").order(order);
      for (const key of extra[table] || []) query = query.order(key);
      const q = await query.range(start, start + 499);
      if (q.error) throw new Error("Unable to load " + table);
      rows.push(...q.data);
      if (q.data.length < 500) return rows;
    }
  }
  const tables = await Promise.all([
    all("skills"),
    all("careers"),
    all("departments"),
    all("industries"),
    all("skill_categories"),
    all("career_required_skills", "skill_id"),
    all("student_skills", "skill_id"),
    all("student_interests", "industry_id"),
    all("opportunities"),
    all("opportunity_skills", "skill_id"),
    all("opportunity_careers", "career_id"),
    all("opportunity_departments", "department_id"),
    all("saved_opportunities", "opportunity_id"),
  ]);
  const [
    skills,
    careers,
    departments,
    industries,
    categories,
    requirements,
    ratings,
    interests,
    opps,
    links,
    careerLinks,
    deptLinks,
    saved,
  ] = tables;
  const opportunities = opps.map((o) => ({
    ...o,
    skills: links
      .filter((l) => l.opportunity_id === o.id)
      .map((l) => ({
        ...skills.find((s) => s.id === l.skill_id),
        weight: l.weight,
      })),
    careers: careerLinks
      .filter((l) => l.opportunity_id === o.id)
      .map((l) => careers.find((c) => c.id === l.career_id)?.slug),
    departments: deptLinks
      .filter((l) => l.opportunity_id === o.id)
      .map((l) => l.department_id),
  })) as unknown as Opportunity[];
  return {
    profile,
    skills,
    careers,
    departments,
    industries,
    categories,
    requirements,
    ranks: Object.fromEntries(
      ratings.map((r) => [
        skills.find((s) => s.id === r.skill_id)?.slug,
        r.proficiency_rank,
      ]),
    ),
    interests: interests.map((r) => r.industry_id),
    opportunities,
    saved: saved.map((r) => r.opportunity_id),
  } as Dataset;
});
