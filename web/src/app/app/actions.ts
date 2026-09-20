"use server";
import { session } from "@/lib/data";
import type { FormState } from "@/lib/types";
import { revalidatePath } from "next/cache";
import { z } from "zod";
function text(f: FormData, key: string) {
  return String(f.get(key) || "").trim();
}
function number(f: FormData, key: string) {
  const value = text(f, key);
  return value === "" ? null : Number(value);
}
export async function saveAcademic(
  _: FormState,
  f: FormData,
): Promise<FormState> {
  const { db, user } = await session();
  const input = z
    .object({
      full_name: z.string().min(1).max(100),
      department_id: z.number().int().positive().nullable(),
      target_career_id: z.number().int().positive().nullable(),
      level: z
        .union([
          z.literal(100),
          z.literal(200),
          z.literal(300),
          z.literal(400),
          z.literal(500),
          z.literal(600),
          z.literal(700),
        ])
        .nullable(),
      cgpa: z.number().min(0).max(5).nullable(),
      data_consent: z.boolean(),
    })
    .safeParse({
      full_name: text(f, "full_name"),
      department_id: number(f, "department_id"),
      target_career_id: number(f, "target_career_id"),
      level: number(f, "level"),
      cgpa: number(f, "cgpa"),
      data_consent: f.get("consent") === "on",
    });
  if (!input.success)
    return {
      error: "Check your name, department, career, level, and CGPA (0–5).",
    };
  try {
    const { error } = await db
      .from("profiles")
      .update({
        ...input.data,
        consent_at: input.data.data_consent ? new Date().toISOString() : null,
        consent_version: "web-1",
      })
      .eq("id", user.id);
    if (error)
      return { error: "Your profile could not be saved. Please try again." };
    revalidatePath("/app", "layout");
    revalidatePath("/onboarding");
    return {
      success:
        "Profile saved. " +
        (input.data.data_consent
          ? "Personalized recommendations are enabled."
          : "Personalization and usage analytics are paused."),
    };
  } catch {
    return {
      error:
        "Connection interrupted. Your changes were not confirmed; please retry.",
    };
  }
}
export async function saveSkills(
  _: FormState,
  f: FormData,
): Promise<FormState> {
  const { db } = await session();
  const ratings = Array.from(f.entries())
    .filter(([k]) => /^skill_\d+$/.test(k))
    .map(([k, v]) => ({ skill_id: Number(k.slice(6)), rank: Number(v) }));
  if (
    !ratings.length ||
    ratings.some((r) => !Number.isInteger(r.rank) || r.rank < 0 || r.rank > 4)
  )
    return { error: "Choose a skill level from 0 to 4." };
  try {
    const { error } = await db.rpc("save_my_skills", { ratings });
    if (error) return { error: "Skills could not be saved. Please try again." };
    revalidatePath("/app", "layout");
    revalidatePath("/onboarding");
    return { success: "Your skill ratings are saved." };
  } catch {
    return { error: "Could not connect. Please retry saving your ratings." };
  }
}
export async function saveInterests(
  _: FormState,
  f: FormData,
): Promise<FormState> {
  const { db } = await session();
  const ids = f.getAll("industry").map(Number);
  if (ids.some((n) => !Number.isInteger(n) || n < 1))
    return { error: "Choose valid interests." };
  const { error } = await db.rpc("save_my_interests", { industry_ids: ids });
  if (error)
    return { error: "Interests could not be saved. Please try again." };
  revalidatePath("/app", "layout");
  revalidatePath("/onboarding");
  return { success: "Interests saved." };
}
export async function toggleSaved(
  _: FormState,
  f: FormData,
): Promise<FormState> {
  const { db, user } = await session();
  const id = text(f, "id");
  if (!z.uuid().safeParse(id).success) return { error: "Invalid opportunity." };
  const remove = f.get("remove") === "true";
  try {
    const result = remove
      ? await db
          .from("saved_opportunities")
          .delete()
          .eq("student_id", user.id)
          .eq("opportunity_id", id)
      : await db
          .from("saved_opportunities")
          .upsert(
            { student_id: user.id, opportunity_id: id },
            { onConflict: "student_id,opportunity_id" },
          );
    if (result.error) return { error: "Could not update saved opportunities." };
    revalidatePath("/app", "layout");
    return { success: remove ? "Removed from saved." : "Opportunity saved." };
  } catch {
    return { error: "Connection interrupted. Please retry." };
  }
}
export async function sendFeedback(
  _: FormState,
  f: FormData,
): Promise<FormState> {
  const { db, user } = await session();
  const category = text(f, "category"),
    body = text(f, "body"),
    rating = number(f, "rating");
  if (
    !["problem", "idea", "experience", "account"].includes(category) ||
    body.length < 10 ||
    body.length > 4000 ||
    (rating !== null && (!Number.isInteger(rating) || rating < 1 || rating > 5))
  )
    return {
      error:
        "Choose a category and write 10–4,000 characters. A rating is optional.",
    };
  const requestId = text(f, "request_id");
  if (!z.uuid().safeParse(requestId).success)
    return { error: "Please refresh this form and try again." };
  try {
    const { error } = await db
      .from("feedback_requests")
      .insert({
        id: requestId,
        student_id: user.id,
        category,
        body,
        usefulness: rating,
        allow_contact: f.get("contact") === "on",
        contact_email: f.get("contact") === "on" ? user.email : null,
        page_path: text(f, "page").slice(0, 150),
        app_version: "web-0.1",
      });
    if (error && error.code !== "23505")
      return {
        error:
          "Feedback could not be sent. Please retry; your text is still here.",
      };
    revalidatePath("/app/feedback");
    return {
      success:
        "Thank you. Your feedback is recorded. You can track its status below.",
    };
  } catch {
    return { error: "Could not send feedback. Please try again." };
  }
}
export async function reviewFeedback(
  _: FormState,
  f: FormData,
): Promise<FormState> {
  const { db, profile } = await session();
  if (profile.role !== "admin") return { error: "Access denied." };
  const status = text(f, "status");
  if (!["new", "reviewing", "resolved"].includes(status))
    return { error: "Choose a valid status." };
  const id = text(f, "id");
  if (!z.uuid().safeParse(id).success) return { error: "Invalid report." };
  const { error } = await db
    .from("feedback_requests")
    .update({ status })
    .eq("id", id);
  if (error) return { error: "Could not update this report." };
  const note = text(f, "note");
  if (note) {
    if (note.length > 4000)
      return {
        error: "Status saved, but the note must be under 4,000 characters.",
      };
    const { error: n } = await db
      .from("feedback_notes")
      .insert({ feedback_id: id, author_id: profile.id, body: note });
    if (n) return { error: "Status saved, but the note could not be saved." };
  }
  revalidatePath("/app/admin");
  return { success: "Review saved." };
}
