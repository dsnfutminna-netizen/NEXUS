"use client";
import Link from "next/link";
import { useState } from "react";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Route,
  Compass,
  Bookmark,
  UserRound,
  MessageSquare,
  Settings,
  ShieldCheck,
  Menu,
} from "lucide-react";
const items = [
  ["/app", "Overview", LayoutDashboard],
  ["/app/roadmap", "Skill roadmap", Route],
  ["/app/opportunities", "Opportunities", Compass],
  ["/app/saved", "Saved", Bookmark],
  ["/app/profile", "My profile", UserRound],
  ["/app/feedback", "Help & feedback", MessageSquare],
  ["/app/settings", "Settings", Settings],
] as const;
export function Nav({ admin = false }: { admin?: boolean }) {
  const path = usePathname();
  const [open, setOpen] = useState(false);
  return (
    <>
      <button
        className="mobile-menu"
        aria-expanded={open}
        aria-controls="workspace-nav"
        onClick={() => setOpen(!open)}
      >
        <Menu size={20} />
        {open
          ? "Close menu"
          : "Menu · " +
            (items.find(([url]) => url === path)?.[1] || "Workspace")}
      </button>
      <nav
        id="workspace-nav"
        className={open ? "is-open" : ""}
        aria-label="Main navigation"
      >
        {items.map(([url, label, Icon]) => (
          <Link
            key={url}
            href={url}
            onClick={() => setOpen(false)}
            aria-current={path === url ? "page" : undefined}
            className={path === url ? "active" : ""}
          >
            <Icon size={19} />
            <span>{label}</span>
          </Link>
        ))}
        {admin && (
          <Link href="/app/admin" onClick={() => setOpen(false)}>
            <ShieldCheck size={19} />
            Platform admin
          </Link>
        )}
      </nav>
    </>
  );
}
