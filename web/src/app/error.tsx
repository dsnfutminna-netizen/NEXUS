"use client";
export default function ErrorPage({ reset }: { reset: () => void }) {
  return (
    <main id="main" className="standalone">
      <div className="card">
        <span className="eyebrow">LET’S TRY THAT AGAIN</span>
        <h1>We couldn’t load this page.</h1>
        <p>
          Your connection or the service may be temporarily unavailable. Your
          saved work will be here when you return.
        </p>
        <button onClick={reset}>Try again</button>
        <a className="button secondary" href="/app/feedback">
          Get help
        </a>
      </div>
    </main>
  );
}
