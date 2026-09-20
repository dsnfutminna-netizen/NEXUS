import { session } from "@/lib/data";
export async function GET() {
  const { db, profile } = await session();
  if (profile.role !== "admin")
    return new Response("Forbidden", { status: 403 });
  const rows: Record<string, unknown>[] = [];
  for (let start = 0; ; start += 500) {
    const { data, error } = await db
      .from("feedback_requests")
      .select(
        "id,category,body,status,usefulness,allow_contact,page_path,created_at",
      )
      .order("id")
      .range(start, start + 499);
    if (error) return new Response("Export unavailable", { status: 503 });
    rows.push(...data);
    if (data.length < 500) break;
  }
  const columns = [
    "id",
    "category",
    "body",
    "status",
    "usefulness",
    "allow_contact",
    "page_path",
    "created_at",
  ];
  const escape = (value: unknown) => {
    let s = String(value ?? "");
    if (/^[=+@\-\t\r]/.test(s)) s = "'" + s;
    return '"' + s.replaceAll('"', '""') + '"';
  };
  return new Response(
    [
      columns.join(","),
      ...rows.map((r) => columns.map((c) => escape(r[c])).join(",")),
    ].join("\r\n"),
    {
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": 'attachment; filename="nexus-feedback.csv"',
        "Cache-Control": "private, no-store",
      },
    },
  );
}
