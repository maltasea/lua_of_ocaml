(* Hashtbl + Set + Map stress test.  Exercises polymorphic hashing,
   functor instantiation, and recursive iteration. *)
module SS = Set.Make (String)
module IM = Map.Make (Int)

let words =
  ["apple"; "banana"; "apple"; "cherry"; "banana"; "date"; "apple"]

let () =
  (* Hashtbl: count word frequencies. *)
  let h = Hashtbl.create 16 in
  List.iter (fun w ->
    let n = try Hashtbl.find h w with Not_found -> 0 in
    Hashtbl.replace h w (n + 1)) words;
  let kvs = Hashtbl.fold (fun k v acc -> (k, v) :: acc) h [] in
  let kvs = List.sort compare kvs in
  print_endline "freq:";
  List.iter (fun (k, v) -> Printf.printf "  %s: %d\n" k v) kvs;
  (* Set: unique sorted. *)
  let s = List.fold_left (fun acc w -> SS.add w acc) SS.empty words in
  Printf.printf "uniq: %d %s\n" (SS.cardinal s)
    (String.concat "," (SS.elements s));
  (* Map: int -> string. *)
  let m = List.fold_left (fun acc (i, w) -> IM.add i w acc) IM.empty
    [1, "one"; 3, "three"; 2, "two"; 5, "five"; 4, "four"]
  in
  Printf.printf "map size: %d\n" (IM.cardinal m);
  IM.iter (fun k v -> Printf.printf "  %d -> %s\n" k v) m;
  (* Sequence-like via fold *)
  let total = IM.fold (fun _ s n -> n + String.length s) m 0 in
  Printf.printf "total chars: %d\n" total
