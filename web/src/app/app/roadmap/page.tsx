import Link from "next/link";
import { dataset } from "@/lib/data";
import { gaps, levels } from "@/lib/intelligence";
import { PageHeading } from "@/components/page-heading";
export default async function Roadmap() {
  const d = await dataset(),
    career = d.careers.find((c) => c.id === d.profile.target_career_id);
  if (!d.profile.data_consent || !career)
    return (
      <>
        <PageHeading
          eyebrow="YOUR SKILL ROADMAP"
          title="Give your next step a direction."
          description="Choose a target career and enable personalized recommendations to see your roadmap."
        />
        <Link className="button" href="/app/profile">
          Review my profile →
        </Link>
      </>
    );
  const rows = gaps(d),
    focus = rows.find((g) => g.gap > 0);
  return (
    <>
      <PageHeading
        eyebrow="YOUR SKILL ROADMAP"
        title={"Your path to " + career.name + "."}
        description="A practical guide based on your self-assessment, not a prediction of career success."
      >
        <Link className="button secondary" href="/app/profile#skills">
          Update my skills
        </Link>
      </PageHeading>
      {focus ? (
        <section className="roadmap-focus">
          <span className="eyebrow">START HERE</span>
          <h2>{focus.name}</h2>
          <p>
            Move from <b>{levels[focus.current]}</b> toward{" "}
            <b>{levels[focus.target]}</b>. Try a small project that uses this
            skill, then update your rating when you can work more independently.
          </p>
          <span className="tag">
            {focus.weight === 3
              ? "Core career skill"
              : "Supporting career skill"}
          </span>
        </section>
      ) : (
        <div className="notice">
          <h2>You meet every current target.</h2>
          <p>Put your skills into practice with a project or opportunity.</p>
          <Link href="/app/opportunities">Explore opportunities →</Link>
        </div>
      )}
      <div className="section-heading">
        <h2>Your skills at a glance</h2>
        <span>{rows.length} skills in this pathway</span>
      </div>
      <div className="card roadmap-list">
        {rows.map((g) => (
          <article key={g.id}>
            <div className="roadmap-label">
              <h3>{g.name}</h3>
              <span>
                {g.weight === 3
                  ? "Core skill"
                  : g.weight === 2
                    ? "Important skill"
                    : "Supporting skill"}
              </span>
            </div>
            <div
              className="skill-scale"
              aria-label={`${g.name}: ${levels[g.current]}, target ${levels[g.target]}`}
            >
              <div className="scale-blocks">
                {[1, 2, 3, 4].map((i) => (
                  <span key={i} className={i <= g.current ? "filled" : ""} />
                ))}
              </div>
              <small>
                {levels[g.current]} <span>→ {levels[g.target]}</span>
              </small>
            </div>
            <span className={"tag " + (!g.gap ? "positive" : "")}>
              {g.gap ? "Room to grow" : "On track ✓"}
            </span>
          </article>
        ))}
      </div>
    </>
  );
}
