"use server";
import { supabase, configured } from "@/lib/supabase";
import { authError } from "@/lib/auth-errors";
import type { FormState } from "@/lib/types";
import { redirect } from "next/navigation";
import { z } from "zod";
const emailSchema = z.email().max(254);
function site() {
  const envUrl = process.env.NEXT_PUBLIC_SITE_URL;
  const vercelUrl = process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : null;
  const url = envUrl && !envUrl.includes("localhost") ? envUrl : (vercelUrl || envUrl || "http://localhost:3005");
  return new URL(url).origin;
}
export async function authenticate(
  _: FormState,
  form: FormData,
): Promise<FormState> {
  let destination = "/app";
  const email = String(form.get("email") || "")
      .trim()
      .toLowerCase(),
    password = String(form.get("password") || ""),
    mode = String(form.get("mode"));
  if (!emailSchema.safeParse(email).success)
    return { error: "Enter a valid email address." };
  if (!configured()) {
    return {
      error:
        "Supabase setup required: Please update NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY in web/.env.local with your Supabase credentials.",
    };
  }
  try {
    const db = await supabase();
    if (mode === "login") {
      const { error } = await db.auth.signInWithPassword({ email, password });
      if (error) return { error: authError(error.code) };
      const {
        data: { user },
      } = await db.auth.getUser();
      if (!user) return { error: "Please try signing in again." };
      const { data: profile, error: profileError } = await db
        .from("profiles")
        .select("id,target_career_id")
        .eq("id", user.id)
        .maybeSingle();
      if (profileError)
        return { error: "We could not load your profile. Please try again." };
      if (!profile?.target_career_id) destination = "/onboarding";
      if (!profile) {
        const { error: insertError } = await db
          .from("profiles")
          .insert({
            id: user.id,
            email: user.email,
            full_name: String(user.user_metadata?.full_name || "Student").slice(
              0,
              100,
            ),
          });
        if (insertError)
          return {
            error: "We could not prepare your profile. Please try again.",
          };
      }
    } else if (mode === "signup") {
      const name = String(form.get("name") || "").trim();
      if (!name || name.length > 100 || password.length < 8)
        return {
          error: "Enter your name and a password of at least 8 characters.",
        };
      const { data, error } = await db.auth.signUp({
        email,
        password,
        options: {
          data: { full_name: name },
          emailRedirectTo: site() + "/auth/callback",
        },
      });
      if (error) return { error: authError(error.code) };

      if (data.session && data.user) {
        const { error: profileError } = await db.from("profiles").upsert(
          {
            id: data.user.id,
            email: data.user.email,
            full_name: name,
          },
          { onConflict: "id" },
        );
        if (profileError)
          return {
            error: "Could not prepare your profile. Please try signing in.",
          };
        destination = "/onboarding";
      } else if (data.user && (data.user.identities?.length ?? 0) === 0) {
        return {
          success:
            "You may already have an account. Try signing in, or contact support if you cannot access it.",
        };
      } else {
        return {
          success:
            process.env.NEXT_PUBLIC_EMAIL_DELIVERY_ENABLED === "true"
              ? "Check your email for a confirmation link. After confirming, return here to sign in."
              : "Your account needs email confirmation, but email delivery is not ready. Contact support so we can help you get started.",
        };
      }
    } else if (mode === "reset") {
      if (process.env.NEXT_PUBLIC_EMAIL_DELIVERY_ENABLED !== "true")
        return { error: "Email recovery is temporarily unavailable. Contact support for account help." };
      const { error } = await db.auth.resetPasswordForEmail(email, {
        redirectTo: site() + "/auth/callback?next=/reset-password",
      });
      if (error) return { error: authError(error.code) };
      return {
        success:
          "If an account exists for this email, a password-reset link has been requested. Check your inbox and spam folder.",
      };
    } else if (mode === "resend") {
      if (process.env.NEXT_PUBLIC_EMAIL_DELIVERY_ENABLED !== "true")
        return { error: "Confirmation emails are temporarily unavailable. Contact support for account help." };
      const { error } = await db.auth.resend({
        type: "signup",
        email,
        options: { emailRedirectTo: site() + "/auth/callback" },
      });
      if (error) return { error: authError(error.code) };
      return {
        success:
          "If confirmation is needed, a new email has been requested. Check your inbox and spam folder.",
      };
    } else return { error: "Invalid request." };
  } catch {
    return {
      error:
        "Authentication is temporarily unavailable. Please try again shortly.",
    };
  }
  redirect(destination);
}
export async function logout() {
  const db = await supabase();
  await db.auth.signOut({ scope: "local" });
  redirect("/login");
}
export async function updatePassword(
  _: FormState,
  form: FormData,
): Promise<FormState> {
  const password = String(form.get("password") || "");
  if (password.length < 8 || password !== form.get("confirm"))
    return {
      error: "Use at least 8 characters and enter the same password twice.",
    };
  try {
    const db = await supabase();
    const { data } = await db.auth.getUser();
    if (!data.user)
      return {
        error:
          "This reset link has expired. Request a new one from the sign-in page.",
      };
    const { error } = await db.auth.updateUser({ password });
    if (error) return { error: authError(error.code) };
    await db.auth.signOut({ scope: "local" });
    return {
      success: "Password updated. You can now sign in with your new password.",
    };
  } catch {
    return { error: "Could not update your password. Please try again." };
  }
}
