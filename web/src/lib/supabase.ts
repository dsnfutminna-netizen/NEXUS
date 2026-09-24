import "server-only";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
export function configured() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  return (
    !!url &&
    !!key &&
    !url.includes("YOUR_") &&
    !key.includes("YOUR_")
  );
}
export async function supabase() {
  if (!configured()) throw new Error("SERVICE_CONFIGURATION");
  const jar = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll: () => jar.getAll(),
        setAll: (values) => {
          try {
            values.forEach(({ name, value, options }) =>
              jar.set(name, value, options),
            );
          } catch {
            /* Server Components cannot set cookies; proxy refreshes them. */
          }
        },
      },
    },
  );
}
