let () =
  let show = function
    | Some n -> "Some " ^ string_of_int n
    | None -> "None"
  in
  print_endline (show (Some 7));
  print_endline (show None);
  let x = Option.map (fun n -> n * 2) (Some 5) in
  print_endline (show x);
  let go = function Ok n -> "ok " ^ string_of_int n | Error s -> "err " ^ s in
  print_endline (go (Ok 3));
  print_endline (go (Error "boom"))
