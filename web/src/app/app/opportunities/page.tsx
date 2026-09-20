import { dataset } from "@/lib/data";
import { sample, expired, earlyCareer, score } from "@/lib/intelligence";
import { OpportunityCard } from "@/components/opportunity-card";
import { PageHeading } from "@/components/page-heading";
import Link from "next/link";
export default async function Opportunities({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | undefined>>;
}) {
  const q = await searchParams,
    d = await dataset();
  let rows = d.opportunities.filter(
    (o) =>
      !expired(o) &&
      sample(o) === (q.samples === "yes") &&
      (!q.q ||
        (
          o.title +
          " " +
          o.organization +
          " " +
          o.skills.map((s) => s.name).join(" ")
        )
          .toLowerCase()
          .includes(q.q.toLowerCase())) &&
      (!q.category || o.category === q.category) &&
      (!q.early || earlyCareer(o)) &&
      (!q.remote || o.is_remote),
  );
  rows.sort((a, b) =>
    q.sort === "deadline"
      ? (a.deadline || "9999").localeCompare(b.deadline || "9999")
      : d.profile.data_consent
        ? score(d, b).score - score(d, a).score
        : a.title.localeCompare(b.title),
  );
  const page = Math.min(
    Math.max(1, Math.ceil(rows.length / 9)),
    Math.max(1, Math.floor(Number(q.page)) || 1),
  );
  function pageUrl(n: number) {
    const p = new URLSearchParams(
      Object.entries(q).filter(
        (e): e is [string, string] => typeof e[1] === "string",
      ),
    );
    p.set("page", String(n));
    return "/app/opportunities?" + p;
  }
  return (
    <>
      <PageHeading
        eyebrow="EXPLORE WHAT’S POSSIBLE"
        title="Your next opportunity is out there."
        description="Explore the possibilities. Read the requirements. Make your own next move."
      />
      <form className="filters">
        <label className="search-field">
          Search opportunities
          <input
            name="q"
            defaultValue={q.q}
            placeholder="Role, skill, or organization…"
          />
        </label>
        <label>
          Type
          <select name="category" defaultValue={q.category || ""}>
            <option value="">All opportunities</option>
            {[...new Set(d.opportunities.map((o) => o.category))]
              .sort()
              .map((c) => (
                <option key={c}>{c}</option>
              ))}
          </select>
        </label>
        <label>
          Sort by
          <select name="sort" defaultValue={q.sort || "relevant"}>
            <option value="relevant">
              {d.profile.data_consent ? "Most relevant" : "Title"}
            </option>
            <option value="deadline">Deadline soonest</option>
          </select>
        </label>
        <button>Search</button>
        <div className="filter-checks">
          <label className="check">
            <input
              type="checkbox"
              name="early"
              value="yes"
              defaultChecked={!!q.early}
            />
            Early career
          </label>
          <label className="check">
            <input
              type="checkbox"
              name="remote"
              value="yes"
              defaultChecked={!!q.remote}
            />
            Remote
          </label>
          <label className="check">
            <input
              type="checkbox"
              name="samples"
              value="yes"
              defaultChecked={q.samples === "yes"}
            />
            Sample listings only
          </label>
          <Link href="/app/opportunities">Clear filters</Link>
        </div>
      </form>
      <p className="fine-print">
        {rows.length} opportunities · Listings and tags are not verified. Remote
        does not always mean worldwide; check the original source.
      </p>
      {rows.length ? (
        <div className="opportunity-grid">
          {rows.slice((page - 1) * 9, page * 9).map((o) => (
            <OpportunityCard key={o.id} o={o} d={d} />
          ))}
        </div>
      ) : (
        <div className="empty">
          <h2>No opportunities in this view.</h2>
          <p>Try a broader search or clear your filters.</p>
          <Link href="/app/opportunities">Clear filters →</Link>
        </div>
      )}
      <div className="pagination">
        {page > 1 && (
          <Link className="button secondary" href={pageUrl(page - 1)}>
            ← Previous
          </Link>
        )}
        {page * 9 < rows.length && (
          <Link className="button secondary" href={pageUrl(page + 1)}>
            Next →
          </Link>
        )}
      </div>
    </>
  );
}
