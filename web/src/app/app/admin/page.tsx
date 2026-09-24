import { notFound } from "next/navigation";
import Link from "next/link";
import { session } from "@/lib/data";
import { PageHeading } from "@/components/page-heading";
import { ActionForm } from "@/components/form";
import { reviewFeedback } from "@/app/app/actions";
export default async function Admin({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; category?: string }>;
}) {
  const { db, profile } = await session();
  if (profile.role !== "admin") notFound();
  const q = await searchParams;
  let query = db
    .from("feedback_requests")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(100);
  if (["new", "reviewing", "resolved"].includes(q.status || ""))
    query = query.eq("status", q.status!);
  if (q.category) query = query.eq("category", q.category);
  const { data: reports, error } = await query;
  const { data: notes } = await db
    .from("feedback_notes")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(500);

  const { count: studentCount } = await db
    .from("profiles")
    .select("*", { count: "exact", head: true });
  const { count: oppCount } = await db
    .from("opportunities")
    .select("*", { count: "exact", head: true });
  const { count: openCount } = await db
    .from("feedback_requests")
    .select("*", { count: "exact", head: true })
    .neq("status", "resolved");

  return (
    <>
      <PageHeading
        eyebrow="PILOT ADMINISTRATION"
        title="Listen. Learn. Improve."
        description="Monitor system activity, student onboarding, and review pilot feedback in real time."
      >
        <Link className="button secondary" href="/app/admin/export">
          Export feedback CSV ↓
        </Link>
      </PageHeading>

      <div className="stats">
        <div>
          <span>
            <b>{studentCount ?? 0}</b> registered students
          </span>
        </div>
        <div>
          <span>
            <b>{oppCount ?? 0}</b> active opportunities
          </span>
        </div>
        <div>
          <span>
            <b>{openCount ?? 0}</b> open feedback issues
          </span>
        </div>
        <div>
          <span>
            <b>{reports?.length ?? 0}</b> total reports in view
          </span>
        </div>
      </div>
      <form className="filters">
        <label>
          Status
          <select name="status" defaultValue={q.status || ""}>
            <option value="">All statuses</option>
            <option>new</option>
            <option>reviewing</option>
            <option>resolved</option>
          </select>
        </label>
        <label>
          Category
          <select name="category" defaultValue={q.category || ""}>
            <option value="">All categories</option>
            {["problem", "idea", "experience", "account"].map((c) => (
              <option key={c}>{c}</option>
            ))}
          </select>
        </label>
        <button>Filter reports</button>
      </form>
      {error && (
        <p className="notice error">
          Could not load feedback. Check that the web migration is applied.
        </p>
      )}
      {reports?.length
        ? reports.map((r) => (
            <section className="card form-card" key={r.id}>
              <div className="section-heading">
                <span className="eyebrow">
                  {r.category} ·{" "}
                  {new Date(r.created_at).toLocaleDateString("en-GB")}
                </span>
                <span className="tag">{r.status}</span>
              </div>
              <p className="description">{r.body}</p>
              <p className="fine-print">
                Usefulness: {r.usefulness || "Not rated"} · Contact permission:{" "}
                {r.allow_contact ? "Yes" : "No"} · Page: {r.page_path}
              </p>
              <p className="fine-print">
                {r.allow_contact && r.contact_email
                  ? "Contact: " + r.contact_email
                  : "Do not contact: permission not given."}
              </p>
              <ActionForm action={reviewFeedback} label="Save review">
                <input type="hidden" name="id" value={r.id} />
                <label>
                  Status
                  <select name="status" defaultValue={r.status}>
                    <option>new</option>
                    <option>reviewing</option>
                    <option>resolved</option>
                  </select>
                </label>
                <label>
                  Internal note
                  <textarea name="note" maxLength={4000} rows={2} />
                </label>
              </ActionForm>
              {notes
                ?.filter((n) => n.feedback_id === r.id)
                .map((n) => (
                  <p key={n.id} className="internal-note">
                    <b>Internal note:</b> {n.body}
                  </p>
                ))}
            </section>
          ))
        : !error && (
            <div className="empty">
              <h2>No feedback in this view.</h2>
              <p>New reports will appear here as students submit them.</p>
            </div>
          )}
    </>
  );
}
