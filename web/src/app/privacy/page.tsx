import Link from "next/link";
import { Brand } from "@/components/brand";
export default function Privacy() {
  return (
    <>
      <header className="public-nav">
        <Brand />
        <Link href="/app">My workspace →</Link>
      </header>
      <main id="main" className="standalone prose">
        <span className="eyebrow">PRIVACY & DATA</span>
        <h1>Your information, explained.</h1>
        <p>
          NEXUS is a DSN FUTMinna student pilot. We store your account details,
          the profile information you choose to provide, skill ratings,
          interests, saved opportunities, and feedback.
        </p>
        <h2>Why we use it</h2>
        <p>
          With your consent, we use your profile to suggest skills and rank
          opportunities. These are transparent rules based on self-assessed
          skills and extracted listing tags. They are not hiring decisions or
          guarantees of eligibility. Pilot usage analytics require consent too.
        </p>
        <h2>Your choices</h2>
        <p>
          You can edit your profile and withdraw recommendation and analytics
          consent in Settings. You can still browse opportunities without
          personalized rankings. Withdrawing consent does not erase saved
          information. Request deletion through Help & feedback or your pilot
          facilitator.
        </p>
        <h2>Who can access it</h2>
        <p>
          Your records are protected by per-user database access policies.
          Authorized operators maintain the service. Pilot administrators can
          review feedback and internal review notes. Other students cannot read
          your profile or feedback. We do not publish student profiles.
        </p>
        <h2>Feedback and contact</h2>
        <p>
          Feedback is voluntary. Reports record your message, category,
          submission time, app version, and page context. You can separately
          allow the team to contact you about a report. Do not include passwords
          or sensitive information in feedback.
        </p>
        <h2>Service providers</h2>
        <p>
          The website is designed for Vercel hosting, with Supabase providing
          account and database services. The pilot team must configure an email
          provider for account confirmation and password recovery. Information
          may be processed outside Nigeria.
        </p>
        <h2>Retention and requests</h2>
        <p>
          The pilot team is responsible for reviewing retention and deletion
          requests. A final retention schedule and named contact must be
          published before wider release. For now, contact the facilitator who
          invited you.
        </p>
        <Link className="button" href="/app/settings">
          Manage my preferences
        </Link>
      </main>
    </>
  );
}
