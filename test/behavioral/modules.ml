module type SHOW = sig
  type t
  val show : t -> string
end

module IntShow : SHOW with type t = int = struct
  type t = int
  let show = string_of_int
end

module PairShow (A : SHOW) (B : SHOW) : SHOW with type t = A.t * B.t = struct
  type t = A.t * B.t
  let show (a, b) = "(" ^ A.show a ^ ", " ^ B.show b ^ ")"
end

module IntIntShow = PairShow (IntShow) (IntShow)

let () =
  print_endline (IntShow.show 42);
  print_endline (IntIntShow.show (3, 4))
