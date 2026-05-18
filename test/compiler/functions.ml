let sq x = x * x

let add a b = a + b

let () =
  let r1 = sq 5 in
  let r2 = add 3 4 in
  ignore (r1, r2)
