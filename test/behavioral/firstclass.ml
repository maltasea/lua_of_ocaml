module type ADD = sig
  type t
  val zero : t
  val add : t -> t -> t
  val show : t -> string
end

module IntAdd : ADD with type t = int = struct
  type t = int
  let zero = 0
  let add = (+)
  let show = string_of_int
end

let sum_all (type a) (module M : ADD with type t = a) xs =
  List.fold_left M.add M.zero xs

let () =
  let m = (module IntAdd : ADD with type t = int) in
  print_endline (IntAdd.show (sum_all m [1; 2; 3; 4; 5]))
