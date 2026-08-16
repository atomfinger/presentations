import gleam/list
import gleam/string

/// Small, deliberately low-tech way to give each node's terminal output a
/// distinct, consistent colour - easier to follow with several terminal
/// windows side by side than matching plain text. `central` is always
/// green; every other label gets a colour picked deterministically from a
/// fixed palette, so this scales to any number of query nodes - three,
/// narrated by hand, or twenty, started all at once by scripts/run-swarm.sh
/// - without needing a hardcoded case per label.
const palette = ["31", "33", "34", "35", "36", "91", "93", "94", "95", "96"]

pub fn for_label(label: String) -> String {
  case label {
    "central" -> "32"
    _ -> {
      let sum =
        label
        |> string.to_utf_codepoints
        |> list.fold(0, fn(acc, cp) { acc + string.utf_codepoint_to_int(cp) })
      let index = sum % list.length(palette)
      case list.first(list.drop(palette, index)) {
        Ok(color) -> color
        Error(Nil) -> "37"
      }
    }
  }
}

pub fn paint(text: String, label: String) -> String {
  "\u{1b}[" <> for_label(label) <> "m" <> text <> "\u{1b}[0m"
}
