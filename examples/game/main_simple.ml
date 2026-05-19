external lg_print : string -> int -> int -> unit = "lg_print"
external _set_update : (float -> unit) -> unit = "_set_update"
external _set_draw : (unit -> unit) -> unit = "_set_draw"
let x = ref 100
let update _dt = x := \!x + 2
let draw () = lg_print "hello" \!x 100
let () = _set_update update; _set_draw draw
