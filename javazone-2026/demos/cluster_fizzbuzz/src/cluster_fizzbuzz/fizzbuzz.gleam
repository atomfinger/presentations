import gleam/int

pub fn compute(n: Int) -> String {
  case n % 15, n % 3, n % 5 {
    0, _, _ -> "FizzBuzz"
    _, 0, _ -> "Fizz"
    _, _, 0 -> "Buzz"
    _, _, _ -> int.to_string(n)
  }
}
