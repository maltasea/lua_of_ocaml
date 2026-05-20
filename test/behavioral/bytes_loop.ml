(* Regression for memory.md task #12:
   merge-block precompilation is gated at <500 blocks, so the post-loop
   `print_newline ()` here is lost on the loop-exit path.  Stays as
   XFAIL until the codegen limitation is fixed. *)
let () =
  let b = Bytes.make 5 'x' in
  Bytes.set b 2 'Y';
  for i = 0 to Bytes.length b - 1 do
    print_char (Bytes.get b i)
  done;
  print_newline ()
