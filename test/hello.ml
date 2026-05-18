let greet name =
  let msg = "hello " ^ name in
  print_endline msg

let () =
  greet "world";
  let x = 1 + 2 in
  if x = 3 then
    print_string "ok"
  else
    print_string "no"
