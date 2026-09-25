"use client";
import { useState } from "react";
import type { Dataset } from "@/lib/types";
import { ActionForm } from "./form";
import { saveAcademic, saveSkills, saveInterests } from "@/app/app/actions";
import { levels } from "@/lib/intelligence";
export function Academic({ d, next }: { d: Dataset; next?: string }) {
  const p = d.profile;
  const otherDeptId = d.departments.find(
    (dep) => dep.name.toLowerCase() === "other"
  )?.id;
  const [deptId, setDeptId] = useState<string>(String(p.department_id || ""));

  return (
    <ActionForm
      key={next}
      action={saveAcademic}
      successHref={next}
      label={next ? "Save and continue →" : "Save profile"}
    >
      <div className="form-grid">
        <label>
          Full name
          <input
            name="full_name"
            defaultValue={p.full_name}
            required
            maxLength={100}
            autoComplete="name"
          />
        </label>
        <label>
          Target career
          <select
            name="target_career_id"
            defaultValue={p.target_career_id || ""}
          >
            <option value="">Choose your direction</option>
            {d.careers.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </label>
        <label>
          Department
          <select
            name="department_id"
            value={deptId}
            onChange={(e) => setDeptId(e.target.value)}
          >
            <option value="">Select department</option>
            {d.departments.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </label>
        {otherDeptId && Number(deptId) === otherDeptId && (
          <label>
            Specify Department
            <input
              name="custom_department"
              maxLength={100}
              placeholder="e.g. Agricultural & Bioresources Engineering"
            />
          </label>
        )}
        <label>
          Level
          <select name="level" defaultValue={p.level || ""}>
            <option value="">Select level</option>
            {[100, 200, 300, 400, 500, 600, 700].map((c) => (
              <option key={c}>{c}</option>
            ))}
          </select>
        </label>
        <label>
          CGPA (optional, 0–5)
          <input
            name="cgpa"
            type="number"
            step="0.01"
            min="0"
            max="5"
            defaultValue={p.cgpa ?? ""}
            placeholder="e.g. 3.50"
          />
        </label>
      </div>
      <label className="check">
        <input type="checkbox" name="consent" defaultChecked={p.data_consent} />
        <span>
          Use my profile for personalized recommendations and platform usage
          analytics.
          <small>
            Optional. You can withdraw this in Settings. Your saved profile and
            voluntary feedback remain stored until you request deletion.
          </small>
        </span>
      </label>
    </ActionForm>
  );
}
export function Skills({ d, next }: { d: Dataset; next?: string }) {
  const required = new Set(
    d.requirements
      .filter((r) => r.career_id === d.profile.target_career_id)
      .map((r) => r.skill_id),
  );
  const ordered = [...d.skills].sort(
    (a, b) =>
      Number(required.has(b.id)) - Number(required.has(a.id)) ||
      a.name.localeCompare(b.name),
  );
  return (
    <ActionForm
      key={next}
      action={saveSkills}
      successHref={next}
      label={next ? "Save and continue →" : "Save skill ratings"}
    >
      <details className="explain">
        <summary>What do these skill levels mean?</summary>
        <p>
          <b>Beginner:</b> follow a guided example. <b>Intermediate:</b>{" "}
          complete familiar tasks with some help. <b>Advanced:</b> work
          independently. <b>Expert:</b> handle unfamiliar problems and guide
          others.
        </p>
      </details>
      {d.categories.map((category) => (
        <details
          className="skill-group"
          key={category.id}
          open={category.id === d.categories[0]?.id}
        >
          <summary>
            {category.name}
            <span>
              {d.skills.filter((s) => s.category_id === category.id).length}{" "}
              skills
            </span>
          </summary>
          <div className="skill-ratings">
            {ordered
              .filter((s) => s.category_id === category.id)
              .map((s) => (
                <label key={s.id}>
                  <span>
                    {s.name}
                    {required.has(s.id) && (
                      <small>For your target career</small>
                    )}
                  </span>
                  <select
                    name={"skill_" + s.id}
                    defaultValue={d.ranks[s.slug] || 0}
                    aria-label={s.name + " proficiency"}
                  >
                    {levels.map((l, i) => (
                      <option key={i} value={i}>
                        {l}
                      </option>
                    ))}
                  </select>
                </label>
              ))}
          </div>
        </details>
      ))}
    </ActionForm>
  );
}
export function Interests({ d, next }: { d: Dataset; next?: string }) {
  return (
    <ActionForm
      key={next}
      action={saveInterests}
      successHref={next}
      label={next ? "Save and continue →" : "Save interests"}
    >
      <div className="interest-grid">
        {d.industries.map((i) => (
          <label key={i.id} className="interest">
            <input
              type="checkbox"
              name="industry"
              value={i.id}
              defaultChecked={d.interests.includes(i.id)}
            />
            {i.name}
          </label>
        ))}
      </div>
    </ActionForm>
  );
}
