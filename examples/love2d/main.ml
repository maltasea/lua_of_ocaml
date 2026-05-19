(* Chicken jump — simple LÖVE2D platformer via OCaml -> Lua FFI *)

(* ---- LÖVE2D FFI bindings ---- *)
external lg_set_color : float -> float -> float -> float -> unit = "lg_set_color"
external lg_rectangle : string -> int -> int -> int -> int -> unit = "lg_rectangle"
external lg_print     : string -> int -> int -> unit = "lg_print"
external lg_clear     : float -> float -> float -> float -> unit = "lg_clear"
external lg_get_width : unit -> int = "lg_get_width"
external lg_get_height : unit -> int = "lg_get_height"
external lk_is_down   : string -> bool = "lk_is_down"
external le_quit      : unit -> unit = "le_quit"
external _set_update  : (float -> unit) -> unit = "_set_update"
external _set_draw    : (unit -> unit) -> unit = "_set_draw"

(* ---- Game state ---- *)
type player = { mutable x : int; mutable y : int; mutable vy : int }

let p = { x = 280; y = 200; vy = 0 }

let ground_y = 350
let gravity = 1
let jump_force = -12
let speed = 4

(* Platforms: (x, y, w) *)
let platforms = [| (100, 300, 80); (250, 250, 80); (400, 200, 80) |]

(* ---- Update ---- *)
let update _dt =
  (* horizontal *)
  if lk_is_down "right" then p.x <- p.x + speed;
  if lk_is_down "left"  then p.x <- p.x - speed;
  (* jump *)
  if lk_is_down "space" && p.y = ground_y then p.vy <- jump_force;
  (* gravity *)
  p.vy <- p.vy + gravity;
  p.y <- p.y + p.vy;
  (* floor *)
  if p.y > ground_y then (p.y <- ground_y; p.vy <- 0);
  (* platform collisions *)
  Array.iter (fun (px, py, pw) ->
    if p.vy > 0
       && p.y >= py && p.y - p.vy <= py
       && p.x + 20 > px && p.x < px + pw
    then (p.y <- py; p.vy <- 0)
  ) platforms;
  (* wrap *)
  if p.x < -20 then p.x <- 600;
  if p.x > 600 then p.x <- -20

(* ---- Draw ---- *)
let draw () =
  lg_clear 0.2 0.3 0.5 1.0;
  (* platforms *)
  lg_set_color 0.4 0.3 0.2 1.0;
  Array.iter (fun (px, py, pw) ->
    lg_rectangle "fill" px py pw 10
  ) platforms;
  (* ground *)
  lg_rectangle "fill" 0 (ground_y + 30) 600 20;
  (* player *)
  lg_set_color 1.0 0.8 0.2 1.0;
  lg_rectangle "fill" p.x p.y 20 30;
  (* eyes *)
  lg_set_color 0.0 0.0 0.0 1.0;
  lg_rectangle "fill" (p.x + 12) (p.y + 5) 4 4;
  lg_rectangle "fill" (p.x + 4) (p.y + 5) 4 4;
  (* beak *)
  lg_set_color 1.0 0.4 0.0 1.0;
  lg_rectangle "fill" (p.x + 6) (p.y + 12) 8 4;
  (* HUD *)
  lg_set_color 1.0 1.0 1.0 1.0;
  lg_print "chicken jump!" 10 10;
  lg_print "arrows=move space=jump esc=quit" 10 30

let () =
  _set_update update;
  _set_draw draw
