import gleam/string

pub opaque type ValidEmail {
  ValidEmail(value: String)
}

// Only this module can create an Email
pub fn new(raw: String) -> Result(ValidEmail, String) {
  case string.contains(raw, "@") {
    True -> Ok(ValidEmail(raw))
    _ -> Error("Invalid email")
  }
}

pub fn get_address(email: ValidEmail) {
  email.value
}
