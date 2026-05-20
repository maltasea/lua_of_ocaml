let () =
  let a = [|10; 20; 30|] in
  a.(1) <- 7;
  print_int a.(0); print_newline ();
  print_int a.(1); print_newline ();
  print_int a.(2); print_newline ();
  print_int (Array.length a); print_newline ();
  let b = Array.make 4 9 in
  print_int b.(0); print_newline ();
  print_int (Array.length b); print_newline ()
