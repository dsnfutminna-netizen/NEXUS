import { Brand } from "@/components/brand";
import { Nav } from "@/components/nav";
import { session } from "@/lib/data";
import Link from "next/link";
import { logout } from "@/app/auth/actions";
export const dynamic = "force-dynamic";
export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { profile } = await session();
  return (
    <div className="workspace">
      <aside className="sidebar">
        <Brand />
        <p className="workspace-label">YOUR CAREER WORKSPACE</p>
        <Nav admin={profile.role === "admin"} />
        <div className="sidebar-foot">
          <div className="pilot-tag">
            <i />
            DSN FUTMinna pilot
          </div>
          <p>A little progress, every day.</p>
        </div>
      </aside>
      <div className="workspace-body">
        <header className="topbar">
          <span className="topbar-label">
            Build skills. Find your direction.
          </span>
          <Link className="feedback-link" href="/app/feedback">
            Give feedback ↗
          </Link>
          <Link
            className="avatar"
            aria-label="Your profile"
            href="/app/profile"
          >
            {profile.full_name.slice(0, 1).toUpperCase()}
          </Link>
          <form action={logout}>
            <button className="text-button">Log out</button>
          </form>
        </header>
        <main id="main" className="content">
          {children}
        </main>
        <footer className="app-footer">
          NEXUS · Built for your next step{" "}
          <Link href="/privacy">Privacy & data</Link>
        </footer>
      </div>
    </div>
  );
}
