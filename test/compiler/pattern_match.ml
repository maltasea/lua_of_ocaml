let () =
  let x = Some 42 in
  let r = match x with Some n -> n | None -> 0 in
  let l = [1; 2; 3] in
  let h = match l with h :: _ -> h | [] -> 0 in
  ignore (r, h)
