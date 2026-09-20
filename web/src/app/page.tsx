import Link from "next/link";
import {
  ArrowUpRight,
  Check,
  Compass,
  Route,
  Bookmark,
  ArrowRight,
} from "lucide-react";
import { Brand } from "@/components/brand";
export default function Home() {
  return (
    <>
      <header className="public-nav">
        <Brand />
        <nav aria-label="Public navigation">
          <a href="#how-it-works">How it works</a>
          <Link href="/login">Sign in</Link>
          <Link className="button" href="/login?mode=signup">
            Get started <ArrowUpRight size={16} />
          </Link>
        </nav>
      </header>
      <main id="main">
        <section className="hero">
          <div className="hero-copy">
            <span className="pilot-tag">
              <i /> BUILT FOR FUTMINNA STUDENTS
            </span>
            <h1>
              Your potential.
              <br />A clearer <em>path.</em>
            </h1>
            <p>
              Turn “what’s next?” into a plan. Discover the skills to build,
              opportunities to explore, and a next step that feels right for
              you.
            </p>
            <div className="hero-actions">
              <Link className="button" href="/login?mode=signup">
                Find my next step <ArrowRight size={18} />
              </Link>
              <a className="text-link" href="#how-it-works">
                See how it works ↓
              </a>
            </div>
            <div className="hero-note">
              <span className="mini-avatars">
                <i>A</i>
                <i>M</i>
                <i>T</i>
              </span>
              <span>
                Designed for students.
                <br />
                <b>Built around your goals.</b>
              </span>
            </div>
          </div>
          <div
            className="hero-visual"
            aria-label="Illustrative example of a NEXUS skill roadmap"
          >
            <div className="orbit orbit-one" />
            <div className="orbit orbit-two" />
            <div className="preview-card">
              <div className="preview-top">
                <span className="eyebrow">YOUR DIRECTION</span>
                <span className="tag">Illustration</span>
              </div>
              <h2>Data Scientist</h2>
              <p>A goal. A few skills. A place to start.</p>
              <div className="preview-progress">
                <span>Build your foundation</span>
                <Route size={19} />
              </div>
              {[
                ["Python", "Ready to practise", 78],
                ["Data analysis", "Your next focus", 42],
                ["Communication", "Keep building", 62],
              ].map(([n, l, v]) => (
                <div className="preview-skill" key={n}>
                  <div>
                    <b>{n}</b>
                    <small>{l}</small>
                  </div>
                  <div className="bar">
                    <i style={{ width: v + "%" }} />
                  </div>
                </div>
              ))}
              <div className="preview-next">
                <span className="check-circle">
                  <Check size={18} />
                </span>
                <div>
                  <b>One useful next step</b>
                  <small>Explore a project using a real dataset.</small>
                </div>
              </div>
            </div>
            <div className="floating-note">
              <Compass size={22} />
              <div>
                <b>Possibility, meet direction.</b>
                <small>Your journey is yours to shape.</small>
              </div>
            </div>
          </div>
        </section>
        <section id="how-it-works" className="how-section">
          <div className="section-intro">
            <span className="eyebrow">LESS GUESSWORK. MORE DIRECTION.</span>
            <h2>
              From where you are
              <br />
              to what comes next.
            </h2>
            <p>
              No perfect profile needed. Start with what you know and build from
              there.
            </p>
          </div>
          <div className="how-grid">
            {[
              [
                Route,
                "01",
                "Know your next skill",
                "Compare your current skills with your career goal and find a practical place to start.",
              ],
              [
                Compass,
                "02",
                "Explore possibilities",
                "Discover opportunities, understand the requirements, and decide what is right for you.",
              ],
              [
                Bookmark,
                "03",
                "Make progress your way",
                "Save useful opportunities, update your skills, and come back to your next step.",
              ],
            ].map(([Icon, n, t, p]) => {
              const I = Icon as typeof Route;
              return (
                <article key={String(n)}>
                  <div className="how-icon">
                    <I size={25} />
                    <span>{String(n)}</span>
                  </div>
                  <h3>{String(t)}</h3>
                  <p>{String(p)}</p>
                </article>
              );
            })}
          </div>
        </section>
        <section className="cta">
          <div>
            <span className="eyebrow">YOU DON’T NEED ALL THE ANSWERS.</span>
            <h2>Just a place to start.</h2>
          </div>
          <Link className="button light" href="/login?mode=signup">
            Create your NEXUS account <ArrowUpRight size={18} />
          </Link>
        </section>
      </main>
      <footer className="public-footer">
        <Brand />
        <span>DSN FUTMinna · Built for your next step.</span>
        <Link href="/privacy">Privacy & data</Link>
      </footer>
    </>
  );
}
