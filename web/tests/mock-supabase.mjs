// Local-only API double for browser flow tests. This is not a Supabase/RLS test.
import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
const fixture = JSON.parse(
  readFileSync(new URL("./parity.json", import.meta.url), "utf8"),
)[0].d;
const id = "00000000-0000-4000-8000-000000000001";
const user = {
  id,
  aud: "authenticated",
  role: "authenticated",
  email: "ada@example.test",
  email_confirmed_at: new Date().toISOString(),
  user_metadata: { full_name: "Ada Student" },
  app_metadata: { provider: "email", providers: ["email"] },
  created_at: new Date().toISOString(),
};
const tables = {
  skills: fixture.skills,
  careers: fixture.careers,
  departments: [{ id: 1, name: "Computer Science", faculty: "SICT" }],
  industries: [{ id: 1, name: "Technology & Software" }],
  skill_categories: [{ id: 1, name: "Skills for your next step" }],
  career_required_skills: fixture.requirements,
  profiles: [{ ...fixture.profile, id, full_name: "Ada Student" }],
  student_skills: fixture.skills
    .filter((s) => fixture.ranks[s.slug])
    .map((s) => ({
      student_id: id,
      skill_id: s.id,
      proficiency_rank: fixture.ranks[s.slug],
    })),
  student_interests: [],
  opportunities: fixture.opportunities.map((o, i) => ({
    ...o,
    id: `00000000-0000-4000-8000-${String(i + 20).padStart(12, "0")}`,
    source: i === 0 ? "live" : "sample",
    url: i === 0 ? "https://careers.example.edu/opportunity" : o.url,
    is_active: true,
  })),
  opportunity_skills: [],
  opportunity_careers: [],
  opportunity_departments: [],
  saved_opportunities: [],
  feedback_requests: [],
  feedback_notes: [],
};
for (const slug of new Set(tables.opportunities.flatMap((o) => o.careers))) {
  if (!tables.careers.some((c) => c.slug === slug))
    tables.careers.push({
      id: tables.careers.length + 1,
      slug,
      name: slug.replaceAll("-", " "),
    });
}
for (const o of tables.opportunities) {
  for (const s of o.skills)
    tables.opportunity_skills.push({
      opportunity_id: o.id,
      skill_id: tables.skills.find((x) => x.slug === s.slug).id,
      weight: s.weight,
    });
  for (const c of o.careers)
    tables.opportunity_careers.push({
      opportunity_id: o.id,
      career_id: tables.careers.find((x) => x.slug === c).id,
    });
}
function token() {
  const b = (v) => Buffer.from(JSON.stringify(v)).toString("base64url");
  return (
    b({ alg: "HS256", typ: "JWT" }) +
    "." +
    b({
      sub: id,
      role: "authenticated",
      aud: "authenticated",
      email: user.email,
      exp: Math.floor(Date.now() / 1000) + 3600,
      iat: Math.floor(Date.now() / 1000),
    }) +
    ".local-test-signature"
  );
}
createServer(async (req, res) => {
  let raw = "";
  for await (const chunk of req) raw += chunk;
  const body = raw ? JSON.parse(raw) : {};
  const url = new URL(req.url, "http://127.0.0.1");
  const respond = (data, status = 200) => {
    res.writeHead(status, {
      "content-type": "application/json",
      "x-supabase-api-version": "2024-01-01",
    });
    res.end(JSON.stringify(data));
  };
  if (url.pathname === "/health") return respond({ ok: true });
  if (url.pathname === "/auth/v1/token") {
    tables.profiles[0].role =
      body.email === "admin@example.test" ? "admin" : "student";
    if (body.password === "wrong-password")
      return respond(
        { code: "invalid_credentials", msg: "Invalid login credentials" },
        400,
      );
    return respond({
      access_token: token(),
      refresh_token: "test-refresh",
      expires_in: 3600,
      expires_at: Math.floor(Date.now() / 1000) + 3600,
      token_type: "bearer",
      user,
    });
  }
  if (url.pathname === "/auth/v1/user") return respond(user);
  if (url.pathname.startsWith("/auth/")) return respond({});
  const name = url.pathname.split("/").pop();
  if (url.pathname.includes("/rpc/")) {
    if (name === "save_my_skills") {
      for (const r of body.ratings) {
        tables.student_skills = tables.student_skills.filter(
          (x) => x.skill_id !== r.skill_id,
        );
        if (r.rank)
          tables.student_skills.push({
            student_id: id,
            skill_id: r.skill_id,
            proficiency_rank: r.rank,
          });
      }
    }
    if (name === "save_my_interests")
      tables.student_interests = body.industry_ids.map((industry_id) => ({
        student_id: id,
        industry_id,
      }));
    return respond(null);
  }
  if (!(name in tables)) return respond({ message: "Unknown table" }, 404);
  let rows = tables[name];
  const matches = (r) =>
    [...url.searchParams].every(
      ([k, v]) => !v.startsWith("eq.") || String(r[k]) === v.slice(3),
    );
  if (req.method === "POST") {
    const values = Array.isArray(body) ? body : [body];
    for (const v of values) {
      if (v.id && rows.some((r) => r.id === v.id))
        return respond({ code: "23505" }, 409);
      rows.push({
        id: randomUUID(),
        created_at: new Date().toISOString(),
        status: "new",
        ...v,
      });
    }
    return respond(values, 201);
  }
  if (req.method === "PATCH") {
    rows.filter(matches).forEach((r) => Object.assign(r, body));
    return respond(rows.filter(matches));
  }
  if (req.method === "DELETE") {
    tables[name] = rows.filter((r) => !matches(r));
    return respond([]);
  }
  rows = rows.filter(matches);
  if (url.searchParams.has("limit"))
    rows = rows.slice(0, Number(url.searchParams.get("limit")));
  if ((req.headers.accept || "").includes("vnd.pgrst.object"))
    return rows.length ? respond(rows[0]) : respond({ code: "PGRST116" }, 406);
  respond(rows);
}).listen(54329, "127.0.0.1", () =>
  console.log("Isolated test API on 127.0.0.1:54329"),
);
