let show = function
  | `Red -> "red"
  | `Green -> "green"
  | `Blue -> "blue"
  | `Hex n -> Printf.sprintf "hex %d" n

let () =
  print_endline (show `Red);
  print_endline (show `Green);
  print_endline (show `Blue);
  print_endline (show (`Hex 255))
