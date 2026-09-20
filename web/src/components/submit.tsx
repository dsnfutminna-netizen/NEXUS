"use client";
import { useFormStatus } from "react-dom";
export function Submit({
  children,
  pending = "Saving…",
  className = "",
}: {
  children: React.ReactNode;
  pending?: string;
  className?: string;
}) {
  const status = useFormStatus();
  return (
    <button type="submit" disabled={status.pending} className={className}>
      {status.pending ? pending : children}
    </button>
  );
}
