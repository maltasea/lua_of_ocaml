(* Chicken jump — raylib via OCaml -> Lua FFI *)

(* ---- Raylib FFI bindings ---- *)
external rl_init_window  : int -> int -> string -> unit = "rl_init_window"
external rl_window_should_close : unit -> bool = "rl_window_should_close"
external rl_begin_drawing : unit -> unit = "rl_begin_drawing"
external rl_clear_bg : float -> float -> float -> float -> unit = "rl_clear_bg"
external rl_draw_rect : int -> int -> int -> int -> float -> float -> float -> float -> unit = "rl_draw_rect"
external rl_draw_text : string -> int -> int -> int -> float -> float -> float -> float -> unit = "rl_draw_text"
external rl_end_drawing : unit -> unit = "rl_end_drawing"
external rl_close_window : unit -> unit = "rl_close_window"
external rl_is_key_down : int -> bool = "rl_is_key_down"

external rl_get_fps : unit -> int = "rl_get_fps"

(* ---- Game state ---- *)
let px = ref 280
let py = ref 200
let vy = ref 0
let ground_y = 350
let gravity = 1
let jump_force = -12
let speed = 4

let platforms = [| (100, 300, 80); (250, 250, 80); (400, 200, 80) |]

let update () =
  if rl_is_key_down 262 (*right*) then px := !px + speed;
  if rl_is_key_down 263 (*left*)  then px := !px - speed;
  if rl_is_key_down 32 (*space*) && !py = ground_y then vy := jump_force;
  vy := !vy + gravity;
  py := !py + !vy;
  if !py > ground_y then (py := ground_y; vy := 0);
  Array.iter (fun (plx, ply, plw) ->
    if !vy > 0
       && !py >= ply && !py - !vy <= ply
       && !px + 20 > plx && !px < plx + plw
    then (py := ply; vy := 0)
  ) platforms;
  if !px < -20 then px := 600;
  if !px > 600 then px := -20

let draw () =
  rl_begin_drawing ();
  rl_clear_bg 0.2 0.3 0.5 1.0;
  (* platforms *)
  Array.iter (fun (plx, ply, plw) ->
    rl_draw_rect plx ply plw 10 0.4 0.3 0.2 1.0
  ) platforms;
  rl_draw_rect 0 (ground_y + 30) 600 20 0.3 0.5 0.3 1.0;
  (* player *)
  rl_draw_rect !px !py 20 30 1.0 0.8 0.2 1.0;
  (* eyes *)
  rl_draw_rect (!px + 12) (!py + 5) 4 4 0.0 0.0 0.0 1.0;
  rl_draw_rect (!px + 4) (!py + 5) 4 4 0.0 0.0 0.0 1.0;
  rl_draw_text "chicken jump!" 10 10 16 1.0 1.0 1.0 1.0;
  rl_end_drawing ()

let () =
  rl_init_window 600 400 "chicken jump — raylib";
  while not (rl_window_should_close ()) do
    update ();
    draw ()
  done;
  rl_close_window ()
