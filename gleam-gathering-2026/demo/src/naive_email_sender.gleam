import gleam/result

pub fn send_welcome_email(email: String) -> Result(String, String) {
  // Send email to user...
  Ok("Welcome email sent to " <> email)
}
