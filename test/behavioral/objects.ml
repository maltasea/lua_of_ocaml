(* Classes and object literals.  Real fix turned out to be three
   things: (1) caml_get_public_method/caml_set_oo_id wired up to match
   jsoo's obj.js, (2) Code.Pushtrap's pcall body now treats Poptrap as
   a branch to the join (its return propagates through pcall as _res,
   then the success branch returns _res), (3) Code.Array_set's index
   formula was off by 2 — `y+1` instead of `y/2+2` — so instance-
   variable writes went to the wrong slot. *)
class counter init = object
  val mutable n = init
  method get = n
  method incr = n <- n + 1
end

let () =
  let c = new counter 10 in
  c#incr; c#incr; c#incr;
  print_int c#get; print_newline ()
