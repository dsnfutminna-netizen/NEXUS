import Link from "next/link";
import {
  ArrowUpRight,
  Route,
  Compass,
  Bookmark,
  ArrowRight,
} from "lucide-react";
import { dataset } from "@/lib/data";
import { gaps, completeness, score, sample, expired } from "@/lib/intelligence";
import { PageHeading } from "@/components/page-heading";
import { OpportunityCard } from "@/components/opportunity-card";
export default async function Dashboard() {
  const d = await dataset(),
    pct = completeness(d),
    career = d.careers.find((c) => c.id === d.profile.target_career_id),
    allGaps = d.profile.data_consent ? gaps(d) : [],
    focus = allGaps.find((g) => g.gap > 0),
    opps = d.opportunities
      .filter((o) => !sample(o) && !expired(o) && o.skills.length)
      .sort((a, b) =>
        d.profile.data_consent
          ? score(d, b).score - score(d, a).score
          : a.title.localeCompare(b.title),
      );
  return (
    <>
      <PageHeading
        eyebrow="YOUR OVERVIEW"
        title={"A little progress, " + d.profile.full_name.split(" ")[0] + "."}
        description="Your goals, your skills, and a clear place to start."
      >
        <span className="date-chip">Your next chapter starts here</span>
      </PageHeading>
      <div className="dashboard-lead">
        <section className="next-step">
          <div className="next-step-top">
            <span className="eyebrow">YOUR NEXT STEP</span>
            <Route size={25} />
          </div>
          <h2>
            {!career
              ? "Choose a direction."
              : !d.profile.data_consent
                ? "Make your experience personal."
                : focus
                  ? "Build confidence in " + focus.name + "."
                  : "Put your skills into practice."}
          </h2>
          <p>
            {!career
              ? "Tell us which career you’re curious about. We’ll help you find the skills to explore."
              : !d.profile.data_consent
                ? "You control how your profile is used. Enable recommendations to see a roadmap based on your goals."
                : focus
                  ? "Choose a small project or short course that uses " +
                    focus.name +
                    ". Aim for one useful piece of work you can explain."
                  : "Your rated skills meet your current career targets. Explore an opportunity where you can apply them."}
          </p>
          <Link
            className="button light"
            href={
              !career
                ? "/app/profile"
                : !d.profile.data_consent
                  ? "/app/settings"
                  : focus
                    ? "/app/roadmap"
                    : "/app/opportunities"
            }
          >
            {!career
              ? "Set my career goal"
              : !d.profile.data_consent
                ? "Review my preferences"
                : focus
                  ? "Explore my skill roadmap"
                  : "Explore opportunities"}
            <ArrowRight size={17} />
          </Link>
          <span className="next-step-decoration" aria-hidden="true">
            ↗
          </span>
        </section>
        <section className="card profile-summary">
          <span className="eyebrow">YOUR FOUNDATION</span>
          <div
            className="progress-ring"
            style={{
              background: `conic-gradient(var(--green) ${pct}%,var(--line) 0)`,
            }}
          >
            <span>
              {pct}
              <small>% complete</small>
            </span>
          </div>
          <h3>{career?.name || "Your future, your choice"}</h3>
          <p>
            {pct === 100
              ? "A strong starting point. Keep your skills up to date."
              : "A few details help make your next step more relevant."}
          </p>
          <Link className="text-link" href="/app/profile">
            {pct === 100 ? "Review profile" : "Complete my profile"}{" "}
            <ArrowUpRight size={16} />
          </Link>
        </section>
      </div>
      <div className="stats">
        <div>
          <Route />
          <span>
            <b>{allGaps.filter((g) => g.gap === 0).length}</b> skills on track
          </span>
        </div>
        <div>
          <Compass />
          <span>
            <b>{opps.length}</b> live opportunities
          </span>
        </div>
        <div>
          <Bookmark />
          <span>
            <b>{d.saved.length}</b> saved for later
          </span>
        </div>
      </div>
      <div className="section-heading">
        <div>
          <span className="eyebrow">A WORLD OF POSSIBILITY</span>
          <h2>Worth exploring</h2>
        </div>
        <Link href="/app/opportunities">
          View all opportunities <ArrowUpRight size={17} />
        </Link>
      </div>
      {opps.length ? (
        <div className="opportunity-grid">
          {opps.slice(0, 3).map((o) => (
            <OpportunityCard key={o.id} o={o} d={d} />
          ))}
        </div>
      ) : (
        <div className="empty">
          <h3>Your next opportunity is on its way.</h3>
          <p>
            The pilot team is preparing current listings. In the meantime,
            explore your skill roadmap.
          </p>
          <Link href="/app/roadmap">Explore my roadmap →</Link>
        </div>
      )}
      <div className="feedback-banner">
        <div>
          <h3>Your experience shapes what comes next.</h3>
          <p>Something helpful, confusing, or missing? We’re listening.</p>
        </div>
        <Link className="button secondary" href="/app/feedback">
          Share feedback ↗
        </Link>
      </div>
    </>
  );
}
