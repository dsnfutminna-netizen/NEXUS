// Central support-contact resolver.
// Set NEXT_PUBLIC_SUPPORT_URL to a support page URL (https://…) or a support
// email address (a bare email is turned into a mailto: link). The published
// support inbox is the default when no deployment override is set.
export function supportHref(): string | null {
  const raw = (
    process.env.NEXT_PUBLIC_SUPPORT_URL ||
    "dsnfutminna@datascientistsfoundation.org"
  ).trim();
  if (!raw) return null;
  if (/^(https?:\/\/|mailto:)/i.test(raw)) return raw;
  if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(raw)) return "mailto:" + raw;
  return null;
}
