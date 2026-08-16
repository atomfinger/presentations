import parse_age.{parse_age}

pub fn a_normal_age_parses_ok_test() {
  assert parse_age("27") == Ok(27)
}

pub fn zero_is_a_valid_age_test() {
  assert parse_age("0") == Ok(0)
}

pub fn a_negative_age_is_rejected_test() {
  assert parse_age("-5") == Error("Cannot have negative age")
}

pub fn non_numeric_input_is_rejected_test() {
  assert parse_age("abc") == Error("\"abc\" is not a number")
}
