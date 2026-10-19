"use client";
import { useEffect } from "react";
import { SupportLink } from "@/components/support-link";

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
          {process.env.NODE_ENV !== "production" &&
          (error?.message?.includes("Unable to load") ||
            error?.message?.includes("SERVICE_CONFIGURATION"))
            ? "Database setup required: ensure Supabase migrations have been applied and environment variables are set."
            : "The service may be temporarily unavailable. Please try again shortly."}
          {error?.digest ? ` Reference: ${error.digest}.` : ""}
        </p>
        <button onClick={reset}>Try again</button>
        <a className="button secondary" href="/login">
          Return to sign in
        </a>
        <p className="fine-print">
          Still stuck? <SupportLink>contact support</SupportLink>.
        </p>
      </div>
    </main>
  );
}
