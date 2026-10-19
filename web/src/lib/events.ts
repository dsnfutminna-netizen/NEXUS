import "server-only";
import { session } from "./data";
// Consent-gated, fire-and-forget analytics. Writes to the `events` table only
// when the user has granted data_consent (the DB also enforces this via RLS).
// Never throws into the calling action — measurement must not break a user flow.
export async function logEvent(
  event_type: string,
  entity?: { type?: string; id?: string; metadata?: Record<string, unknown> },
) {
  try {
    const { db, user, profile } = await session();
    if (!profile.data_consent) return;
    await db.from("events").insert({
      student_id: user.id,
      event_type,
      entity_type: entity?.type ?? null,
      entity_id: entity?.id ?? null,
      metadata: entity?.metadata ?? {},
    });
  } catch {
    /* best-effort: ignore analytics write failures */
  }
}
