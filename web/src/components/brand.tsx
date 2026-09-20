import Link from "next/link";
export function Brand() {
  return (
    <Link className="brand" href="/">
      <span className="brand-icon" aria-hidden="true">
        N<span />
      </span>
      NEXUS<span className="brand-dot">.</span>
    </Link>
  );
}
