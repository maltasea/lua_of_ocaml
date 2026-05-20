(* Bytes mutation + for-loop length.  Regression for the codegen issue
   where post-loop code was lost when the CFG had many blocks. *)
let () =
  let b = Bytes.make 5 'x' in
  Bytes.set b 2 'Y';
  for i = 0 to Bytes.length b - 1 do
    print_char (Bytes.get b i)
  done;
  print_newline ()
