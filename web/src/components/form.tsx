"use client";
import { useRouter } from "next/navigation";
import { useActionState, useRef, useEffect } from "react";
import type { FormState } from "@/lib/types";
import { Submit } from "./submit";
export function ActionForm({
  action,
  children,
  label = "Save changes",
  className = "",
  once = false,
  successHref,
}: {
  action: (state: FormState, data: FormData) => Promise<FormState>;
  children: React.ReactNode;
  label?: string;
  className?: string;
  once?: boolean;
  successHref?: string;
}) {
  const [state, submit] = useActionState(action, {});
  const router = useRouter();
  useEffect(() => {
    if (state.success && successHref) router.push(successHref);
  }, [state, successHref, router]);
  const ref = useRef<HTMLFormElement>(null);
  const snapshot = useRef<FormData | null>(null);
  useEffect(() => {
    if (!state.error || !snapshot.current || !ref.current) return;
    for (const element of Array.from(ref.current.elements)) {
      if (
        element instanceof HTMLInputElement ||
        element instanceof HTMLTextAreaElement ||
        element instanceof HTMLSelectElement
      ) {
        if (element instanceof HTMLInputElement && element.type === "password")
          continue;
        if (
          element instanceof HTMLInputElement &&
          element.type === "checkbox"
        ) {
          element.checked = snapshot.current
            .getAll(element.name)
            .includes(element.value);
        } else {
          const value = snapshot.current.get(element.name);
          if (typeof value === "string") element.value = value;
        }
      }
    }
  }, [state]);
  if (once && state.success)
    return (
      <p className="notice" role="status">
        {state.success}
      </p>
    );
  return (
    <form
      ref={ref}
      action={submit}
      onSubmit={(event) => {
        snapshot.current = new FormData(event.currentTarget);
      }}
      className={"form " + className}
    >
      {children}
      {state.error && (
        <p className="notice error" role="alert">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="notice" role="status">
          {state.success}
        </p>
      )}
      <Submit>{label}</Submit>
    </form>
  );
}
