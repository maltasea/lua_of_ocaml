(* Minimal test: no standard library dependencies *)
let () =
  (* Simple integer arithmetic *)
  let x = 1 + 2 in
  (* Simple string *)
  let _s = "hello" in
  (* Just return x, don't use stdlib *)
  if x <> 3 then
    failwith "bad"
  else
    ()
