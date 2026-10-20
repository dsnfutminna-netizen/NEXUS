"use client";

import { useEffect } from "react";
import { createBrowserClient } from "@supabase/ssr";

// Dashboard-issued recovery emails return to the Supabase Site URL with an
// implicit-flow fragment. The server cannot read that fragment, so exchange it
// for the same cookie-backed session used by the reset form.
export function RecoveryRedirect() {
  useEffect(() => {
    const fragment = new URLSearchParams(window.location.hash.slice(1));
    if (fragment.get("type") !== "recovery") return;

    const access_token = fragment.get("access_token");
    const refresh_token = fragment.get("refresh_token");
    window.history.replaceState(null, "", window.location.pathname + window.location.search);

    if (!access_token || !refresh_token) {
      window.location.replace("/login?notice=expired");
      return;
    }

    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
    if (!url || !key) {
      window.location.replace("/login?notice=expired");
      return;
    }

    const client = createBrowserClient(url, key);
    void client.auth.setSession({ access_token, refresh_token }).then(({ error }) => {
      window.location.replace(error ? "/login?notice=expired" : "/reset-password");
    }).catch(() => window.location.replace("/login?notice=expired"));
  }, []);

  return null;
}
