let () =
  print_int (if [1; 2] = [1; 2] then 1 else 0); print_newline ();
  print_int (if [1; 2] = [1; 3] then 1 else 0); print_newline ();
  print_int (if [1; 2] <> [1; 2; 3] then 1 else 0); print_newline ();
  print_int (if (1, "a") = (1, "a") then 1 else 0); print_newline ();
  print_int (if (1, "a") = (1, "b") then 1 else 0); print_newline ();
  print_int (if Some 5 = Some 5 then 1 else 0); print_newline ();
  print_int (if [1; 2] < [1; 3] then 1 else 0); print_newline ()
