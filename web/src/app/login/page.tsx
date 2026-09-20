import Link from "next/link";
import { Brand } from "@/components/brand";
import { ActionForm } from "@/components/form";
import { authenticate } from "@/app/auth/actions";
export default async function Login({
  searchParams,
}: {
  searchParams: Promise<{ mode?: string; notice?: string }>;
}) {
  const q = await searchParams;
  const mode = ["signup", "reset", "resend"].includes(q.mode || "")
    ? q.mode!
    : "login";
  const title = {
    login: "Welcome back.",
    signup: "Your next chapter starts here.",
    reset: "Let’s get you back in.",
    resend: "Check your inbox.",
  }[mode];
  return (
    <div className="auth-layout">
      <section className="auth-story">
        <Brand />
        <div>
          <span className="eyebrow">YOUR POTENTIAL. A CLEARER PATH.</span>
          <h1>
            Small steps.
            <br />
            Real possibilities.
          </h1>
          <p>
            Understand where you are, discover where you could go, and make your
            next move with confidence.
          </p>
          <div className="auth-steps">
            <p>
              <b>01</b> Tell us about your goals
            </p>
            <p>
              <b>02</b> Find the skills worth building
            </p>
            <p>
              <b>03</b> Explore your next opportunity
            </p>
          </div>
        </div>
        <span>DSN FUTMinna · Student career platform</span>
      </section>
      <main id="main" className="auth-main">
        <Link className="back-link" href="/">
          ← Back to NEXUS
        </Link>
        <div className="auth-form">
          <span className="eyebrow">
            {mode === "signup" ? "CREATE YOUR ACCOUNT" : "YOUR NEXUS ACCOUNT"}
          </span>
          <h1>{title}</h1>
          <p>
            {mode === "login"
              ? "Sign in to pick up where you left off."
              : mode === "signup"
                ? "A few details today. A clearer direction tomorrow."
                : "We’ll send a secure link to your email address."}
          </p>
          {q.notice && (
            <p className="notice error" role="alert">
              {q.notice === "profile"
                ? "We could not prepare your profile. Contact the pilot team."
                : "That link is invalid or expired. Please request a new email below."}
            </p>
          )}
          <ActionForm
            action={authenticate}
            label={
              {
                login: "Sign in →",
                signup: "Create my account →",
                reset: "Send reset link",
                resend: "Resend confirmation",
              }[mode]
            }
          >
            <input type="hidden" name="mode" value={mode} />
            {mode === "signup" && (
              <label>
                Full name
                <input
                  name="name"
                  autoComplete="name"
                  required
                  maxLength={100}
                  placeholder="How should we call you?"
                />
              </label>
            )}
            <label>
              Email address
              <input
                name="email"
                type="email"
                required
                autoComplete="email"
                placeholder="you@example.com"
              />
            </label>
            {["signup", "login"].includes(mode) && (
              <label>
                Password
                <input
                  name="password"
                  type="password"
                  required
                  minLength={mode === "signup" ? 8 : 1}
                  autoComplete={
                    mode === "signup" ? "new-password" : "current-password"
                  }
                />
                {mode === "signup" && (
                  <small>
                    At least 8 characters. Use a password you don’t use
                    elsewhere.
                  </small>
                )}
              </label>
            )}
            {mode === "signup" && (
              <p className="fine-print">
                Your profile is private to your account and authorized pilot
                support. Read{" "}
                <Link href="/privacy">how we handle your data</Link>.
                Recommendation and analytics consent is a separate choice in
                your profile.
              </p>
            )}
          </ActionForm>
          <div className="auth-links">
            {mode === "login" ? (
              <>
                <Link href="/login?mode=reset">Forgot password?</Link>
                <p>
                  New to NEXUS?{" "}
                  <Link href="/login?mode=signup">Create an account</Link>
                </p>
                <Link href="/login?mode=resend">Resend confirmation email</Link>
              </>
            ) : (
              <Link href="/login">Already have an account? Sign in</Link>
            )}
          </div>
          <p className="fine-print">
            Local demo accounts are separate from website accounts.
          </p>
        </div>
      </main>
    </div>
  );
}
