(* Multi-placeholder Printf.  Used to fail with stale captures across
   recursive make_printf calls; works now that Code.Let inside inner
   closures emits a Lua `local` rather than a global write. *)
let () =
  Printf.printf "abc%dxyz\n" 42;
  Printf.printf "%d %s\n" 42 "hi";
  Printf.printf "%d %s %.2f\n" 7 "hi" 3.14
