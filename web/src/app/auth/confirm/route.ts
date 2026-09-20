import { NextResponse, type NextRequest } from "next/server";
import { supabase } from "@/lib/supabase";

// Token-hash email links also work when opened in a different browser.
export async function GET(request: NextRequest) {
  const token_hash = request.nextUrl.searchParams.get("token_hash");
  const type = request.nextUrl.searchParams.get("type");
  if (token_hash && (type === "email" || type === "recovery")) {
    const db = await supabase();
    const { error } = await db.auth.verifyOtp({ token_hash, type });
    if (!error) {
      return NextResponse.redirect(
        new URL(
          type === "recovery" ? "/reset-password" : "/auth/complete",
          request.url,
        ),
      );
    }
  }
  return NextResponse.redirect(new URL("/login?notice=expired", request.url));
}
