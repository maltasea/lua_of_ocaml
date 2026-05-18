let () =
  let l = [1; 2; 3; 4] in
  let n = List.length l in
  let doubled = List.map (fun x -> x * 2) l in
  ignore (n, doubled)
