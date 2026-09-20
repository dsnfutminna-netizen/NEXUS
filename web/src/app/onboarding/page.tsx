import Link from "next/link";
import { dataset } from "@/lib/data";
import { Brand } from "@/components/brand";
import { Academic, Skills, Interests } from "@/components/profile-forms";
export default async function Onboarding({
  searchParams,
}: {
  searchParams: Promise<{ step?: string }>;
}) {
  const q = await searchParams,
    step = Math.min(3, Math.max(1, Number(q.step) || 1)),
    d = await dataset();
  return (
    <>
      <header className="public-nav">
        <Brand />
        <Link href="/app">Finish later →</Link>
      </header>
      <main id="main" className="onboarding">
        <div className="stepper">
          {["Your direction", "Your skills", "Your interests"].map((s, i) => (
            <Link
              key={s}
              href={"/onboarding?step=" + (i + 1)}
              aria-current={step === i + 1 ? "step" : undefined}
            >
              <span>{i + 1}</span>
              {s}
            </Link>
          ))}
        </div>
        <span className="eyebrow">STEP {step} OF 3</span>
        <h1>
          {
            [
              "Let’s find your direction.",
              "Start with what you know.",
              "What sparks your curiosity?",
            ][step - 1]
          }
        </h1>
        <p>
          Start with what you know. Save and continue, or skip a step and return
          to it in your profile.
        </p>
        <div className="card">
          {step === 1 ? (
            <Academic d={d} next="/onboarding?step=2" />
          ) : step === 2 ? (
            <Skills d={d} next="/onboarding?step=3" />
          ) : (
            <Interests d={d} next="/app" />
          )}
        </div>
        <div className="onboarding-next">
          {step > 1 && (
            <Link href={"/onboarding?step=" + (step - 1)}>← Back</Link>
          )}
          <Link
            className="text-link"
            href={step < 3 ? "/onboarding?step=" + (step + 1) : "/app"}
          >
            {step < 3 ? "Skip for now →" : "Skip to my dashboard →"}
          </Link>
        </div>
      </main>
    </>
  );
}
