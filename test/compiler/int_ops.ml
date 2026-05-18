let () =
  let a = 10 land 6 in
  let b = 10 lor 6 in
  let c = 10 lxor 6 in
  let d = 1 lsl 3 in
  let e = 16 lsr 2 in
  let f = min 3 7 in
  let g = max 3 7 in
  let h = abs (-5) in
  ignore (a, b, c, d, e, f, g, h)
