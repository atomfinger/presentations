import sum_numbers.{sum_builtin, sum_recursive}

pub fn sum_recursive_adds_every_number_test() {
  assert sum_recursive([1, 2, 3, 4]) == 10
}

pub fn sum_recursive_of_empty_list_is_zero_test() {
  assert sum_recursive([]) == 0
}

pub fn sum_builtin_adds_every_number_test() {
  assert sum_builtin([1, 2, 3, 4]) == 10
}

pub fn sum_builtin_of_empty_list_is_zero_test() {
  assert sum_builtin([]) == 0
}

pub fn both_approaches_agree_test() {
  let numbers = [5, 12, -3, 8, 0, 100]
  assert sum_recursive(numbers) == sum_builtin(numbers)
}
