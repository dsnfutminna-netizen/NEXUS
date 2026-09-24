import Link from "next/link";
import { dataset } from "@/lib/data";
import { Academic } from "@/components/profile-forms";
import { PageHeading } from "@/components/page-heading";
export default async function Settings() {
  const d = await dataset();
  return (
    <>
      <PageHeading
        eyebrow="YOUR ACCOUNT, YOUR CHOICES"
        title="You’re in control."
        description="Manage your preferences and how your information is used."
      />
      <section className="card form-card">
        <h2>Personalization & consent</h2>
        <p>
          Withdraw consent below to pause personalized results and new usage
          analytics. Your existing profile and feedback remain stored.
        </p>
        <Academic d={d} />
      </section>
      <section className="card form-card">
        <h2>Account access</h2>
        <p>
          Signed in as <b>{d.profile.email}</b>.
        </p>
        <Link className="button secondary" href="/login?mode=reset">
          Request password reset
        </Link>
      </section>
      <section className="card form-card">
        <h2>Request account deletion</h2>
        <p>
          The support team can delete your account and associated personal data.
          Submit an account request so the team can verify ownership and follow
          up.
        </p>
        <Link className="button danger-outline" href="/app/feedback">
          Request account help
        </Link>
        <Link className="text-link" href="/privacy">
          Read our data notice →
        </Link>
      </section>
    </>
  );
}
