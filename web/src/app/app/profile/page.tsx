import { dataset } from "@/lib/data";
import { Academic, Skills, Interests } from "@/components/profile-forms";
import { PageHeading } from "@/components/page-heading";
export default async function Profile() {
  const d = await dataset();
  return (
    <>
      <PageHeading
        eyebrow="YOUR FOUNDATION"
        title="A profile that grows with you."
        description="Start with what you know. Update it as you learn."
      />
      <div className="profile-tabs">
        <a href="#academic">About you</a>
        <a href="#skills">Your skills</a>
        <a href="#interests">Interests</a>
      </div>
      <section id="academic" className="card form-card">
        <h2>About you & your direction</h2>
        <p>
          Your career choice is a starting point. You can change it anytime.
        </p>
        <Academic d={d} />
      </section>
      <section id="skills" className="card form-card">
        <h2>What can you do today?</h2>
        <p>
          Honest ratings lead to a more useful roadmap. You don’t need to rate
          every skill at once.
        </p>
        <Skills d={d} />
      </section>
      <section id="interests" className="card form-card">
        <h2>What interests you?</h2>
        <p>Choose the industries you’d like to explore.</p>
        <Interests d={d} />
      </section>
    </>
  );
}
