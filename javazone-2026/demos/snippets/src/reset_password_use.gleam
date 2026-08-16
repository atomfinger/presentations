import gleam/result

/// Deliberately NOT a real implementation - every validation step is a
/// `todo` stub. The point of this slide isn't "here's how to validate an
/// email," it's "here's what chaining several Result-returning steps
/// actually looks like in real Gleam," without the nested `case`
/// pyramid you'd get from unwrapping each Result by hand.
///
/// This is the same Email -> RegisteredEmail -> VerifiedEmail chain from
/// the Typing section, wired together with `use` + `result.try`.
pub opaque type Email {
  Email(String)
}

pub opaque type RegisteredEmail {
  RegisteredEmail(Email)
}

pub opaque type VerifiedEmail {
  VerifiedEmail(RegisteredEmail)
}

pub fn parse(input: String) -> Result(Email, String) {
  todo as "pretend this checks the email format"
}

pub fn find_registration(email: Email) -> Result(RegisteredEmail, String) {
  todo as "pretend this looks the user up"
}

pub fn require_verified(reg: RegisteredEmail) -> Result(VerifiedEmail, String) {
  todo as "pretend this checks they've verified"
}

pub fn send_password_reset(to: VerifiedEmail) -> Nil {
  todo as "pretend this actually sends the email"
}

pub fn reset_password(input: String) -> Result(Nil, String) {
  use email <- result.try(parse(input))
  use registered <- result.try(find_registration(email))
  use verified <- result.try(require_verified(registered))
  Ok(send_password_reset(verified))
}
