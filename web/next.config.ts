const publicKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || "";
if (publicKey.startsWith("sb_secret_"))
  throw new Error(
    "Use a Supabase publishable key, never a secret key in NEXT_PUBLIC variables.",
  );
if (publicKey.split(".").length === 3) {
  try {
    const role = JSON.parse(
      Buffer.from(publicKey.split(".")[1], "base64url").toString(),
    ).role;
    if (role !== "anon")
      throw new Error("Privileged Supabase key is not permitted.");
  } catch {
    throw new Error("Invalid public Supabase key.");
  }
}
import type { NextConfig } from "next";
const config: NextConfig = {
  poweredByHeader: false,
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "X-Frame-Options", value: "DENY" },
          {
            key: "Permissions-Policy",
            value: "camera=(), microphone=(), geolocation=()",
          },
        ],
      },
    ];
  },
};
export default config;
