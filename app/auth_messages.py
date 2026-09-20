"""Safe authentication messages: never display raw provider errors or credentials."""
def auth_error_message(error, operation):
    code = getattr(error, 'code', None)
    messages = {
        'email_not_confirmed': 'Confirm your email using the link in your inbox before logging in. Check your spam folder too.',
        'email_address_not_authorized': 'Confirmation email could not be sent. The pilot team must configure email delivery before external users can register.',
        'over_email_send_rate_limit': 'The confirmation-email sending limit has been reached. Please wait and contact the pilot team if this continues.',
        'over_request_rate_limit': 'Too many authentication attempts. Please wait a few minutes before trying again.',
        'signup_disabled': 'New account registration is currently disabled. Contact the pilot team.',
        'weak_password': 'Choose a stronger password with at least 8 characters, including letters and numbers.',
        'email_address_invalid': 'Enter a valid email address you can access.',
        'invalid_credentials': 'Email or password is incorrect. Accounts from the local demo do not work here; create a new account on this site.',
    }
    if code in messages:
        return messages[code]
    return ('We could not complete ' + ('sign-in' if operation == 'login' else 'registration') +
            '. Please try again or contact the pilot team. This may be a service or configuration problem.')
