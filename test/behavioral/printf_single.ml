(* Single-placeholder Printf works.  Multi-placeholder is currently
   broken — see printf_multi.ml (xfail). *)
let () =
  Printf.printf "%d\n" 42;
  print_endline (Printf.sprintf "%s" "hi");
  print_endline (Printf.sprintf "%c" 'X');
  print_endline (Printf.sprintf "hello world")
