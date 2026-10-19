import Link from "next/link";
import { Brand } from "@/components/brand";
import { SupportLink } from "@/components/support-link";
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
          NEXUS is a DSN FUTMinna student platform. We store your account details,
          the profile information you choose to provide, skill ratings,
          interests, saved opportunities, and feedback.
        </p>
        <h2>Why we use it</h2>
        <p>
          With your consent, we use your profile to suggest skills and rank
          opportunities. These are transparent rules based on self-assessed
          skills and extracted listing tags. They are not hiring decisions or
          guarantees of eligibility. Platform usage analytics require consent too.
        </p>
        <h2>Your choices</h2>
        <p>
          You can edit your profile and withdraw recommendation and analytics
          consent in Settings. You can still browse opportunities without
          personalized rankings. Withdrawing consent does not erase saved
          information. You can request deletion through{" "}
          <Link href="/app/feedback">Help &amp; feedback</Link> or by{" "}
          <SupportLink>contacting support</SupportLink>.
        </p>
        <h2>Who can access it</h2>
        <p>
          Your records are protected by per-user database access policies.
          Authorized operators maintain the service. Platform administrators can
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
          account and database services. When configured, an email provider is
          used for account confirmation and password recovery. Information may
          be processed outside Nigeria.
        </p>
        <h2>Retention and requests</h2>
        <p>
          We keep your information while your account is active. If you stop
          signing in, we retain your account and profile for six months after
          your last sign-in, then review them for deletion. You can ask us to
          delete your account and personal data sooner. An administrator checks
          ownership, handles verified requests promptly, and confirms when the
          deletion is complete. Start a request
          through <Link href="/app/feedback">Help &amp; feedback</Link> or{" "}
          <SupportLink>contact support</SupportLink>.
        </p>
        <Link className="button" href="/app/settings">
          Manage my preferences
        </Link>
      </main>
    </>
  );
}
