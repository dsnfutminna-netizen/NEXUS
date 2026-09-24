"use server";
import { supabase, configured } from "@/lib/supabase";
import { authError } from "@/lib/auth-errors";
import type { FormState } from "@/lib/types";
import { redirect } from "next/navigation";
import { z } from "zod";
const emailSchema = z.email().max(254);
function site() {
  const url = process.env.NEXT_PUBLIC_SITE_URL;
  if (!url) throw new Error("Missing site URL");
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
      const { error } = await db.auth.signUp({
        email,
        password,
        options: {
          data: { full_name: name },
          emailRedirectTo: site() + "/auth/callback",
        },
      });
      if (error) return { error: authError(error.code) };
      return {
        success:
          "Check your email for a confirmation link. After confirming, return here to sign in.",
      };
    } else if (mode === "reset") {
      const { error } = await db.auth.resetPasswordForEmail(email, {
        redirectTo: site() + "/auth/callback?next=/reset-password",
      });
      if (error) return { error: authError(error.code) };
      return {
        success:
          "If an account exists for this email, a password-reset link has been requested. Check your inbox and spam folder.",
      };
    } else if (mode === "resend") {
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
