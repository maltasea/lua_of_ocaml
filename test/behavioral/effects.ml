(* OCaml 5 effect handlers, implemented via Lua coroutines (which give
   us one-shot continuations directly — exactly what OCaml effects use).
   See runtime/lua/effects.lua. *)
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
