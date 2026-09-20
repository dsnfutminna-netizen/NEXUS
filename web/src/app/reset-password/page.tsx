import Link from "next/link";
import { ActionForm } from "@/components/form";
import { updatePassword } from "@/app/auth/actions";
export default function Reset() {
  return (
    <main id="main" className="standalone">
      <div className="card">
        <h1>Choose a new password</h1>
        <ActionForm action={updatePassword} label="Update password">
          <label>
            New password
            <input
              type="password"
              name="password"
              autoComplete="new-password"
              required
              minLength={8}
            />
          </label>
          <label>
            Confirm password
            <input
              type="password"
              name="confirm"
              autoComplete="new-password"
              required
              minLength={8}
            />
          </label>
        </ActionForm>
        <Link href="/login">Return to sign in</Link>
      </div>
    </main>
  );
}
