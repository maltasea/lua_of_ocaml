let () =
  let b = false in
  print_int (if b then 1 else 0); print_newline ();
  let t = true in
  print_int (if t then 1 else 0); print_newline ();
  print_int (if 1 < 2 then 1 else 0); print_newline ();
  print_int (if 2 < 1 then 1 else 0); print_newline ();
  print_int (if not true then 1 else 0); print_newline ();
  print_int (if not false then 1 else 0); print_newline ()
