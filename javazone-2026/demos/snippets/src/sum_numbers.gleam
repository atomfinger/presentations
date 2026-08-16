import gleam/list

/// Two ways to add up a list of numbers in a language with no `for`, no
/// `while`: do the recursion yourself, or reach for a standard library
/// function that already does it for you. Same signature, same result -
/// this is the "and loops?" beat, made concrete.
///
/// `sum_recursive` is written as a tail call on purpose: the recursive
/// call to `sum_loop` is the very last thing each branch does, with
/// nothing left to do after it returns (unlike `first + sum_recursive(rest)`,
/// which still has an addition waiting once the call comes back). The
/// BEAM compiles a genuine tail call into a jump, not a new stack frame,
/// so this runs in constant stack space no matter how long the list is.
pub fn sum_recursive(numbers: List(Int)) -> Int {
  sum_loop(numbers, 0)
}

fn sum_loop(numbers: List(Int), acc: Int) -> Int {
  case numbers {
    [] -> acc
    [first, ..rest] -> sum_loop(rest, acc + first)
  }
}

pub fn sum_builtin(numbers: List(Int)) -> Int {
  list.fold(numbers, 0, fn(total, n) { total + n })
}
