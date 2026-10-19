"use client";
// Root-level error boundary: catches failures in the root layout itself, which
// a route-level error.tsx cannot. Must render its own <html>/<body>.
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html lang="en">
      <body>
        <main id="main" className="standalone">
          <div className="card">
            <span className="eyebrow">SERVICE NOTICE</span>
            <h1>Something went wrong.</h1>
            <p>
              NEXUS hit an unexpected error. Please try again in a moment.
              {error?.digest ? ` Reference: ${error.digest}.` : ""}
            </p>
            <button onClick={reset}>Try again</button>
            <a className="button secondary" href="/login">
              Return to sign in
            </a>
          </div>
        </main>
      </body>
    </html>
  );
}
