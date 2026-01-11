import gleam/result

pub opaque type ValidEmail {
  ValidEmail(value: String)
}

pub fn new(address: String) -> Result(ValidEmail, String) {
  use _ <- result.try(is_valid_email(address))
  use is_user_registered <- result.try(is_user_registered(address))
  // Other checks?
  case is_user_registered {
    True -> Ok(ValidEmail(address))
    False -> Error("User not registered in the system")
  }
}

pub fn send_welcome_email(email: ValidEmail) -> Result(String, String) {
  // Send email to user
  Ok("Welcome email sent to " <> email.value)
}

fn is_valid_email(_: String) -> Result(Nil, String) {
  Ok(Nil)
}

fn is_user_registered(_: String) -> Result(Bool, String) {
  Ok(True)
}
