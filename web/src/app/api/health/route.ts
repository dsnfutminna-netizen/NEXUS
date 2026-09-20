export async function GET() {
  return Response.json(
    {
      status: "ok",
      application: "nexus-web",
      version: "0.1.0",
      configured:
        !!process.env.NEXT_PUBLIC_SUPABASE_URL &&
        !!process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    },
    { headers: { "Cache-Control": "no-store" } },
  );
}
