import gleam/int

/// A guard clause (`if age < 0`) attached directly to a pattern, rather
/// than a separate `use`/`case` step: one flat `case`, three branches,
/// each one a different reason the input could be bad. This is the
/// concrete code behind the "errors when there are no exceptions" beat -
/// `int.parse` already returns a `Result(Int, Nil)` from the standard
/// library, and `parse_age` just turns that bland `Nil` into an actual
/// message alongside its own negative-age check.
pub fn parse_age(input: String) -> Result(Int, String) {
  case int.parse(input) {
    Ok(age) if age < 0 -> Error("Cannot have negative age")
    Ok(age) -> Ok(age)
    Error(Nil) -> Error("\"" <> input <> "\" is not a number")
  }
}
