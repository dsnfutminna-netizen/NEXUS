import { randomUUID } from "node:crypto";
import { session } from "@/lib/data";
import { PageHeading } from "@/components/page-heading";
import { ActionForm } from "@/components/form";
import { sendFeedback } from "@/app/app/actions";
export default async function Feedback({
  searchParams,
}: {
  searchParams: Promise<{ page?: string }>;
}) {
  const { db, user } = await session(),
    q = await searchParams;
  const { data: reports, error } = await db
    .from("feedback_requests")
    .select("id,category,body,status,created_at")
    .eq("student_id", user.id)
    .order("created_at", { ascending: false })
    .limit(30);
  return (
    <>
      <PageHeading
        eyebrow="WE’RE BUILDING THIS WITH YOU"
        title="Your voice belongs here."
        description="Tell us what helped, what got in your way, or what you’d like to see next."
      />
      <div className="feedback-layout">
        <section className="card form-card">
          <h2>Share your experience</h2>
          {error ? (
            <p className="notice error">
              Feedback is not available yet. Please contact your pilot
              facilitator. The team needs to finish the feedback database setup.
            </p>
          ) : (
            <ActionForm once action={sendFeedback} label="Send feedback →">
              <input type="hidden" name="request_id" value={randomUUID()} />
              <input type="hidden" name="page" value={q.page || "feedback"} />
              <label>
                What would you like to share?
                <select name="category" required defaultValue="">
                  <option value="" disabled>
                    Choose a category
                  </option>
                  <option value="problem">Something isn’t working</option>
                  <option value="idea">An idea or improvement</option>
                  <option value="experience">My experience with NEXUS</option>
                  <option value="account">
                    Account help or deletion request
                  </option>
                </select>
              </label>
              <label>
                Tell us more
                <textarea
                  name="body"
                  rows={6}
                  minLength={10}
                  maxLength={4000}
                  required
                  placeholder="What were you trying to do? What happened? What would make it better?"
                />
                <small>
                  Please don’t include passwords or sensitive personal
                  information.
                </small>
              </label>
              <label>
                How useful has NEXUS been? (optional)
                <select name="rating" defaultValue="">
                  <option value="">Choose a rating</option>
                  {[1, 2, 3, 4, 5].map((n) => (
                    <option key={n} value={n}>
                      {n} —{" "}
                      {
                        [
                          "Not useful",
                          "Slightly useful",
                          "Somewhat useful",
                          "Useful",
                          "Very useful",
                        ][n - 1]
                      }
                    </option>
                  ))}
                </select>
              </label>
              <label className="check">
                <input type="checkbox" name="contact" />
                <span>
                  The pilot team may contact me about this feedback using my
                  account email.
                </span>
              </label>
            </ActionForm>
          )}
        </section>
        <aside>
          <section className="card help-card">
            <span className="eyebrow">A NOTE FROM THE TEAM</span>
            <h2>Honest feedback helps.</h2>
            <p>
              You don’t need to have all the answers. A small detail about your
              experience can help us make NEXUS more useful.
            </p>
            <hr />
            <h3>Need account help?</h3>
            <p>
              Choose account help above, or contact the facilitator who invited
              you. Deletion requests are reviewed by the pilot team.
            </p>
          </section>
        </aside>
      </div>
      <div className="section-heading">
        <h2>Your feedback</h2>
        <span>Latest 30 reports</span>
      </div>
      {reports?.length ? (
        <div className="card">
          {reports.map((r) => (
            <article className="report-row" key={r.id}>
              <div>
                <span className="eyebrow">
                  {r.category} ·{" "}
                  {new Date(r.created_at).toLocaleDateString("en-GB")}
                </span>
                <p>{r.body}</p>
              </div>
              <span className="tag">{r.status}</span>
            </article>
          ))}
        </div>
      ) : (
        <p className="muted">
          Your submitted feedback will appear here with its review status.
        </p>
      )}
    </>
  );
}
