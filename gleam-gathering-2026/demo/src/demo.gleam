import gleam/result
import safe_email_sender as welcome_sender

pub fn main() -> Result(Nil, String) {
  // Ok
  use good_email_result <- result.try(welcome_sender.new(
    "wibbly@wobbly.wabbely",
  ))
  let _ = welcome_sender.send_welcome_email(good_email_result)

  use bad_email_result <- result.try(welcome_sender.new("wibbly"))

  // Code will never reach since "wibbly" is not a valid email
  let _ = welcome_sender.send_welcome_email(bad_email_result)
  //... Code
  Ok(Nil)
}
