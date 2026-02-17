import gleam/result

pub opaque type ValidEmail {
  ValidEmail(value: String)
}

pub opaque type RegisteredEmail {
  RegisteredEmail(value: ValidEmail)
}

pub opaque type VerifiedEmail {
  VerifiedEmail(value: RegisteredEmail)
}

pub opaque type WelcomeEmailRecipient {
  WelcomeEmailRecipient(value: VerifiedEmail)
}

pub fn validate_email(input: String) -> Result(ValidEmail, String) {
  case is_valid_email(input) {
    True -> Ok(ValidEmail(input))
    False -> Error("Invalid email")
  }
}

pub fn register_email(email: ValidEmail) -> Result(RegisteredEmail, String) {
  case email_already_registered(email) {
    False -> Ok(RegisteredEmail(email))
    True -> Error("Email already registered")
  }
}

pub fn verify_email(email: RegisteredEmail) -> Result(VerifiedEmail, String) {
  case verification_confirmed(email) {
    True -> Ok(VerifiedEmail(email))
    False -> Error("Email not verified")
  }
}

pub fn make_welcome_recipient(
  email: VerifiedEmail,
) -> Result(WelcomeEmailRecipient, String) {
  case welcome_already_sent(email) {
    True -> Error("Welcome email already sent")
    False -> Ok(WelcomeEmailRecipient(email))
  }
}

pub fn send_welcome_email(_recipient: WelcomeEmailRecipient) -> Nil {
  // Pretend there's some real good code here.
  Nil
}

pub fn onboard_and_welcome(input: String) -> Result(Nil, String) {
  input
  |> validate_email
  |> result.try(register_email)
  |> result.try(verify_email)
  |> result.try(make_welcome_recipient)
  |> result.map(send_welcome_email)
}

fn is_valid_email(_input: String) -> Bool {
  True
}

fn email_already_registered(_email: ValidEmail) -> Bool {
  False
}

fn verification_confirmed(_email: RegisteredEmail) -> Bool {
  True
}

fn welcome_already_sent(_email: VerifiedEmail) -> Bool {
  False
}
