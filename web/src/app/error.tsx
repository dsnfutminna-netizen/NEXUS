"use client";
import { useEffect } from "react";

export default function ErrorPage({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("NEXUS Page Error:", error);
  }, [error]);

  return (
    <main id="main" className="standalone">
      <div className="card">
        <span className="eyebrow">SERVICE NOTICE</span>
        <h1>We couldn’t load this page.</h1>
        <p>
          {error?.message?.includes("Unable to load") || error?.message?.includes("SERVICE_CONFIGURATION")
            ? "Database setup required: Please ensure Supabase database migrations have been executed and environment variables are set."
            : "Your connection or the service may be temporarily unavailable. Please try again shortly."}
        </p>
        <button onClick={reset}>Try again</button>
        <a className="button secondary" href="/login">
          Return to sign in
        </a>
      </div>
    </main>
  );
}
