(* XFAIL: classes and object literals.  Runtime camlinternalOO support
   (caml_get_public_method, caml_set_oo_id, etc.) is in place, but
   set_method's Labs.find runs before new_method populates the label
   map, raising Not_found.  Either narrow/new_method aren't being
   called or our codegen mishandles the order.  Tracked separately. *)
class counter init = object
  val mutable n = init
  method get = n
  method incr = n <- n + 1
end

let () =
  let c = new counter 10 in
  c#incr; c#incr; c#incr;
  print_int c#get; print_newline ()
