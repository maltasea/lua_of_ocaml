(* Chicken jump — raylib via OCaml -> LuaJIT FFI *)

external rl_init_window  : int -> int -> string -> unit = "rl_init_window"
external rl_window_should_close : unit -> bool = "rl_window_should_close"
external rl_begin        : unit -> unit = "rl_begin"
external rl_end          : unit -> unit = "rl_end"
external rl_clear        : float -> float -> float -> float -> unit = "rl_clear"
external rl_draw_rect    : int -> int -> int -> int -> float -> float -> float -> float -> unit = "rl_draw_rect"
external rl_draw_text    : string -> int -> int -> int -> float -> float -> float -> float -> unit = "rl_draw_text"
external rl_is_key_down  : int -> bool = "rl_is_key_down"

type player = { mutable x : int; mutable y : int; mutable vy : int }
let p = { x = 280; y = 200; vy = 0 }
let ground_y = 350
let gravity = 1
let jump_force = -12
let speed = 4

let update () =
  if rl_is_key_down 524 then p.x <- p.x + speed;   (* KEY_RIGHT  *)
  if rl_is_key_down 526 then p.x <- p.x - speed;   (* KEY_LEFT   *)
  if rl_is_key_down 64 && p.y = ground_y then p.vy <- jump_force; (* KEY_SPACE *)
  p.vy <- p.vy + gravity;
  p.y <- p.y + p.vy;
  if p.y > ground_y then (p.y <- ground_y; p.vy <- 0);
  if p.x < -20 then p.x <- 600;
  if p.x > 600 then p.x <- -20

let draw () =
  rl_begin ();
  rl_clear 0.2 0.3 0.5 1.0;
  rl_draw_rect 0 (ground_y + 30) 600 20 0.3 0.5 0.3 1.0;
  rl_draw_rect 100 300 80 10 0.4 0.3 0.2 1.0;
  rl_draw_rect 250 250 80 10 0.4 0.3 0.2 1.0;
  rl_draw_rect 400 200 80 10 0.4 0.3 0.2 1.0;
  rl_draw_rect p.x p.y 20 30 1.0 0.8 0.2 1.0;
  rl_draw_rect (p.x + 12) (p.y + 5) 4 4 0.0 0.0 0.0 1.0;
  rl_draw_rect (p.x + 4) (p.y + 5) 4 4 0.0 0.0 0.0 1.0;
  rl_draw_text "chicken jump! arrows=move space=jump" 10 10 14 1.0 1.0 1.0 1.0;
  rl_end ()

let () =
  rl_init_window 600 400 "chicken jump — raylib";
  while not (rl_window_should_close ()) do
    update ();
    draw ()
  done
