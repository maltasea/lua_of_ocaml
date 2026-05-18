let rec fact n = if n <= 1 then 1 else n * fact (n - 1)

let rec fib n = if n < 2 then n else fib (n-1) + fib (n-2)

let () =
  ignore (fact 5, fib 6)
