(* LÖVE2D bouncing square demo *)

external lg_set_font  : int -> unit = "lg_set_font"
external lg_clear     : float -> float -> float -> float -> unit = "lg_clear"
external lg_set_color : float -> float -> float -> float -> unit = "lg_set_color"
external lg_rectangle : string -> int -> int -> int -> int -> unit = "lg_rectangle"
external lg_print     : string -> int -> int -> unit = "lg_print"

external _set_update : (float -> unit) -> unit = "_set_update"
external _set_draw   : (unit -> unit) -> unit = "_set_draw"

external lt_get_delta : unit -> float = "lt_get_delta"
external lk_is_down   : string -> bool = "lk_is_down"

let state = ref (100, 100, 2, 2)

let update dt =
  let (x, y, dx, dy) = !state in
  let dx = if lk_is_down "right" then 4 else if lk_is_down "left" then -4 else dx in
  let dy = if lk_is_down "down"  then 4 else if lk_is_down "up"   then -4 else dy in
  state := (x + dx, y + dy, dx, dy)

let draw () =
  lg_clear 0.1 0.1 0.15 1.0;
  let (x, y, _, _) = !state in
  lg_set_color 0.2 0.8 0.3 1.0;
  lg_rectangle "fill" x y 40 40;
  lg_set_color 1.0 1.0 1.0 1.0;
  lg_print "hello from OCaml <-> Lua FFI" 10 10

let () =
  lg_set_font 14;
  _set_update update;
  _set_draw draw
