(* XFAIL: OCaml 5 effect handlers.  These need the runtime primitives
   caml_alloc_stack, resume, perform, reperform,
   caml_continuation_use_noexc, etc.  jsoo implements these via a CPS
   transformation; we don't.  Real support would require a deeper
   codegen rewrite. *)
open Effect
open Effect.Deep
type _ Effect.t += Get : int t

let () =
  let r =
    try_with (fun () -> 100 + perform Get) ()
      { effc = (fun (type a) (eff : a t) ->
          match eff with
          | Get -> Some (fun (k : (a, _) continuation) -> continue k 42)
          | _ -> None) }
  in
  print_int r; print_newline ()
