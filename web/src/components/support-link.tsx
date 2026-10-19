import { supportHref } from "@/lib/support";
// Renders a real support link when NEXT_PUBLIC_SUPPORT_URL is set; otherwise
// falls back to `fallbackHref` (e.g. the in-app feedback form), or plain text
// so we never advertise a channel that does not exist. Neutral component —
// safe to use from both server and client components.
export function SupportLink({
  children = "contact support",
  fallbackHref,
}: {
  children?: React.ReactNode;
  fallbackHref?: string;
}) {
  const href = supportHref() ?? fallbackHref ?? null;
  if (!href) return <>{children}</>;
  const external = /^https?:\/\//i.test(href);
  return (
    <a
      href={href}
      {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
    >
      {children}
    </a>
  );
}
