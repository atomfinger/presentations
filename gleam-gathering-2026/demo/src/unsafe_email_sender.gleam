import gleam/result

pub fn send_welcome_email(email: String) -> Result(String, String) {
  use _ <- result.try(is_valid_email(email))
  use is_user_registered <- result.try(is_user_registered(email))
  // Other checks?

  case is_user_registered {
    True -> {
      // Send email to user
      Ok("Welcome email sent to " <> email)
    }
    False -> Error("User not registered in the system")
  }
}

fn is_valid_email(_: String) -> Result(Nil, String) {
  Ok(Nil)
}

fn is_user_registered(_: String) -> Result(Bool, String) {
  Ok(True)
}
