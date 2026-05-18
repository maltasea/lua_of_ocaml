let make_adder n = fun x -> n + x

let apply_twice f x = f (f x)

let () =
  let add3 = make_adder 3 in
  let r1 = add3 10 in
  let r2 = apply_twice (fun x -> x * 2) 5 in
  ignore (r1, r2)
