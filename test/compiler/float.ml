let () =
  let a = 1.5 +. 2.5 in
  let b = a *. 2.0 in
  let c = b /. 2.0 in
  let d = int_of_float c in
  ignore (a, b, d)
