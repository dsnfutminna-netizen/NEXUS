import Link from "next/link";
import { notFound } from "next/navigation";
import { dataset } from "@/lib/data";
import { score, sample, safeUrl, expired } from "@/lib/intelligence";
import { ActionForm } from "@/components/form";
import { toggleSaved } from "@/app/app/actions";
export default async function Detail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params,
    d = await dataset(),
    o = d.opportunities.find((o) => o.id === id);
  if (!o) notFound();
  const m = score(d, o),
    url = safeUrl(o.url),
    saved = d.saved.includes(id);
  return (
    <>
      <Link className="back-link" href="/app/opportunities">
        ← All opportunities
      </Link>
      <section className="card opportunity-detail">
        <span className="eyebrow">
          {o.organization || "Opportunity"} · {o.category}
        </span>
        <h1>{o.title}</h1>
        <p>
          {o.location || (o.is_remote ? "Remote" : "Location not stated")} ·{" "}
          {o.source}
        </p>
        <div className="detail-actions">
          {!sample(o) && !expired(o) && url ? (
            <a
              className="button"
              href={url}
              target="_blank"
              rel="noopener noreferrer"
            >
              Read original & apply ↗
            </a>
          ) : (
            <p className="notice">
              {sample(o)
                ? "Sample listing. Applications are disabled."
                : expired(o)
                  ? "The recorded deadline has passed."
                  : "Application link unavailable."}
            </p>
          )}
          <ActionForm
            action={toggleSaved}
            label={saved ? "Remove from saved" : "Save for later"}
          >
            <input type="hidden" name="id" value={id} />
            <input type="hidden" name="remove" value={String(saved)} />
          </ActionForm>
        </div>
        <hr />
        <h2>About this opportunity</h2>
        <p className="description">
          {o.description ||
            "Read the original posting for the full description."}
        </p>
        {d.profile.data_consent && (
          <>
            <h2>How your skills connect</h2>
            <p>
              <b>{m.coverage}% tagged skills coverage.</b> This measures overlap
              with extracted skill tags, not your chance of acceptance.
            </p>
            <div className="tags">
              {o.skills.map((s) => (
                <span key={s.slug}>
                  {(d.ranks[s.slug] || 0) > 0 ? "✓ " : ""}
                  {s.name}
                </span>
              ))}
            </div>
            {!m.eligible && (
              <p className="notice error">
                Your profile does not meet the recorded academic limits.
              </p>
            )}
          </>
        )}
        <h2>Before you apply</h2>
        <ul>
          <li>
            Confirm location, work authorization, experience, and skill
            requirements.
          </li>
          <li>Recorded deadline: {o.deadline || "Not stated"}.</li>
          <li>
            Academic level: {o.min_level || "Any"} to {o.max_level || "any"}.
          </li>
          <li>Check availability and legitimacy on the source website.</li>
        </ul>
        <Link href="/app/feedback?page=opportunity">
          Report a problem with this listing →
        </Link>
      </section>
    </>
  );
}
