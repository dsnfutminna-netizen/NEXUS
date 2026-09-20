import { NextResponse, type NextRequest } from "next/server";
import { supabase } from "@/lib/supabase";
export async function GET(request: NextRequest) {
  const db = await supabase();
  const { data } = await db.auth.getUser();
  if (!data.user) return NextResponse.redirect(new URL("/login", request.url));
  const { data: existing } = await db
    .from("profiles")
    .select("id,target_career_id")
    .eq("id", data.user.id)
    .maybeSingle();
  if (!existing) {
    const { error } = await db
      .from("profiles")
      .insert({
        id: data.user.id,
        email: data.user.email,
        full_name: String(
          data.user.user_metadata?.full_name || "Student",
        ).slice(0, 100),
      });
    if (error) {
      const { data: concurrent } = await db
        .from("profiles")
        .select("id")
        .eq("id", data.user.id)
        .maybeSingle();
      if (!concurrent)
        return NextResponse.redirect(
          new URL("/login?notice=profile", request.url),
        );
    }
  }
  return NextResponse.redirect(
    new URL(existing?.target_career_id ? "/app" : "/onboarding", request.url),
  );
}
