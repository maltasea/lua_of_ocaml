let () =
  let xs = List.map (fun n -> n * 10) [1; 2; 3; 4] in
  List.iter (fun n -> print_int n; print_char ' ') xs;
  print_newline ();
  print_int (List.fold_left (+) 0 xs); print_newline ();
  let a = Array.make 4 0 in
  for i = 0 to 3 do a.(i) <- i * i done;
  Array.iter (fun n -> print_int n; print_char ' ') a;
  print_newline ()
