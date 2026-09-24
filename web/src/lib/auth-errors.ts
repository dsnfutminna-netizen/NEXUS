export function authError(code?: string) {
  const messages: Record<string, string> = {
    email_not_confirmed:
      "Please confirm your email first. Check your inbox and spam folder, or resend the confirmation below.",
    invalid_credentials:
      "That email and password do not match. Local demo accounts are separate from website accounts.",
    email_address_not_authorized:
      "Email delivery is not ready for this address. Please contact support.",
    over_email_send_rate_limit:
      "The email sending limit has been reached. Please wait before trying again.",
    over_request_rate_limit: "Too many attempts. Please wait a few minutes.",
    signup_disabled: "Registration is temporarily closed.",
    weak_password: "Choose a stronger password of at least 8 characters.",
    user_already_exists:
      "If you already have an account, sign in or reset your password.",
  };
  return (
    messages[code || ""] ||
    "We could not complete that request. Please try again or contact support."
  );
}
