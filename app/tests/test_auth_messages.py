import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from auth_messages import auth_error_message
class AuthMessageTests(unittest.TestCase):
 def error(self,code):
  error=Exception('sensitive password and token');error.code=code;return error
 def test_confirmation_is_distinct_from_wrong_password(self):
  self.assertIn('Confirm your email',auth_error_message(self.error('email_not_confirmed'),'login'))
  self.assertIn('incorrect',auth_error_message(self.error('invalid_credentials'),'login'))
 def test_delivery_restriction_is_actionable(self):
  self.assertIn('configure email delivery',auth_error_message(self.error('email_address_not_authorized'),'signup'))
 def test_unknown_error_never_exposes_provider_text(self):
  text=auth_error_message(self.error('unknown'),'signup')
  self.assertNotIn('sensitive',text)
  self.assertIn('configuration',text)
if __name__=='__main__':unittest.main()
