let () =
  let b = Buffer.create 16 in
  Buffer.add_string b "hi ";
  Buffer.add_string b "world";
  print_endline (Buffer.contents b);
  let b2 = Buffer.create 4 in
  Buffer.add_char b2 'A';
  print_int (Buffer.length b2); print_newline ();
  print_endline (Buffer.contents b2)
