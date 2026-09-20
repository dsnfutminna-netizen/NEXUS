import Link from "next/link";
import { dataset } from "@/lib/data";
import { OpportunityCard } from "@/components/opportunity-card";
import { PageHeading } from "@/components/page-heading";
export default async function Saved() {
  const d = await dataset(),
    rows = d.opportunities.filter((o) => d.saved.includes(o.id));
  return (
    <>
      <PageHeading
        eyebrow="KEEP THE POSSIBILITIES CLOSE"
        title="Saved for your next move."
        description="A shortlist you can return to. Check deadlines before applying."
      />
      {rows.length ? (
        <div className="opportunity-grid">
          {rows.map((o) => (
            <OpportunityCard key={o.id} o={o} d={d} />
          ))}
        </div>
      ) : (
        <div className="empty">
          <span className="empty-icon">◇</span>
          <h2>Your shortlist starts here.</h2>
          <p>
            See something interesting? Save it and come back when you’re ready.
          </p>
          <Link className="button" href="/app/opportunities">
            Explore opportunities →
          </Link>
        </div>
      )}
    </>
  );
}
