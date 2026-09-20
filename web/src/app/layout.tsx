import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = {
  title: {
    default: "NEXUS — Your next step, made clearer",
    template: "%s · NEXUS",
  },
  description:
    "Build your skills, explore opportunities and take your next step. The DSN FUTMinna student platform.",
};
export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" data-scroll-behavior="smooth">
      <body>
        <a className="skip" href="#main">
          Skip to content
        </a>
        {children}
      </body>
    </html>
  );
}
