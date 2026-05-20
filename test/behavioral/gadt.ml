type _ expr =
  | EInt : int -> int expr
  | EBool : bool -> bool expr
  | EAdd : int expr * int expr -> int expr
  | EEq : int expr * int expr -> bool expr
  | EIf : bool expr * 'a expr * 'a expr -> 'a expr

let rec eval : type a. a expr -> a = function
  | EInt n -> n
  | EBool b -> b
  | EAdd (a, b) -> eval a + eval b
  | EEq (a, b) -> eval a = eval b
  | EIf (c, t, e) -> if eval c then eval t else eval e

let () =
  let e = EIf (EEq (EAdd (EInt 1, EInt 2), EInt 3), EInt 100, EInt 200) in
  print_int (eval e); print_newline ();
  let b = EEq (EInt 5, EInt 6) in
  print_endline (if eval b then "yes" else "no")
