let () =
  let a = 1 + 2 * 3 in
  let b = a - 4 in
  let c = a * b in
  let d = c / 2 in
  let e = if a > b then a else b in
  ignore (a, b, c, d, e)
