(* Microbenchmarks: tight loops with no I/O, used to compare
   ocamlrun bytecode vs luajit compiled output.  Each subtest is sized
   so it runs O(1s) on a modern machine under ocamlrun. *)

let fib n =
  let rec aux n = if n < 2 then n else aux (n - 1) + aux (n - 2) in
  aux n

let sum_array n =
  let a = Array.make n 0 in
  for i = 0 to n - 1 do a.(i) <- i done;
  let s = ref 0 in
  for i = 0 to n - 1 do s := !s + a.(i) done;
  !s

let fold_list n =
  (* Smaller n: deep cons-chains exceed Lua's C stack at our codegen's
     non-tail-call cost (~2000 frames typical).  See misc/bench.md. *)
  let rec build acc i = if i = 0 then acc else build (i :: acc) (i - 1) in
  let xs = build [] n in
  List.fold_left (+) 0 xs

let string_concat n =
  let b = Buffer.create 1024 in
  for _ = 1 to n do Buffer.add_string b "abc" done;
  String.length (Buffer.contents b)

let map_ops n =
  let module M = Map.Make (Int) in
  let m = ref M.empty in
  for i = 0 to n - 1 do m := M.add i (i * 2) !m done;
  let s = ref 0 in
  M.iter (fun _ v -> s := !s + v) !m;
  !s

let closure_calls n =
  let f x = x + 1 in
  let g h x = h x in
  let s = ref 0 in
  for _ = 1 to n do s := g f !s done;
  !s

let time name f =
  let t0 = Sys.time () in
  let r = f () in
  let dt = Sys.time () -. t0 in
  Printf.printf "%-22s %.3fs  -> %d\n%!" name dt r

let () =
  time "fib(30)"               (fun () -> fib 30);
  time "sum_array(1_000_000)"  (fun () -> sum_array 1_000_000);
  time "fold_list(1_000)"      (fun () -> fold_list 1_000);
  time "string_concat(100_000)" (fun () -> string_concat 100_000);
  time "map_ops(50_000)"       (fun () -> map_ops 50_000);
  time "closure_calls(1M)"     (fun () -> closure_calls 1_000_000)
