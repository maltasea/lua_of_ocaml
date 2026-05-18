open Js_of_ocaml_compiler.Stdlib
module Code = Js_of_ocaml_compiler.Code

type ident =
  | S of ident_string
  | V of Code.Var.t

and ident_string =
  { name : string
  ; var : Code.Var.t option
  }

type binop =
  | Add | Sub | Mul | Div | Mod | Pow
  | Concat
  | Eq | Neq | Lt | Le | Gt | Ge
  | And | Or

type unop =
  | Neg | Not | Len

type expression =
  | ENil
  | EBool of bool
  | EStr of string
  | EVar of ident
  | ENum of string
  | ETable of table_field list
  | EFun of ident list * block * bool
  | ECall of expression * expression list
  | EMethod of expression * string * expression list
  | EBin of binop * expression * expression
  | EUn of unop * expression
  | EAccess of expression * expression
  | EDot of expression * string

and table_field =
  | TField of string * expression
  | TArray of expression

and block = statement list

and statement =
  | Block of block
  | Local of ident list * expression list
  | LocalFun of ident * ident list * block
  | Assign of expression list * expression list
  | FunAssign of expression * ident list * block
  | If of expression * block * elseif_clause list * block option
  | While of expression * block
  | Repeat of block * expression
  | ForRange of ident * expression * expression * expression option * block
  | ForIn of ident list * expression list * block
  | Return of expression list
  | Break
  | ExprStmt of expression
  | Comment of string

and elseif_clause = expression * block

type program = statement list

(* ---- Helpers ---- *)

let is_ident_char = function
  | 'a'..'z' | 'A'..'Z' | '_' -> true
  | _ -> false

let is_ident s =
  let len = String.length s in
  len > 0
  && (is_ident_char s.[0] || String.contains "~=+-*/^%<>|&!@#$%^&*()[]{}.,:;'\"?\\`" s.[0])
  && String.for_all s ~f:(fun c ->
         match c with
         | 'a'..'z' | 'A'..'Z' | '0'..'9' | '_' -> true
         | _ -> false)

let ident ?var name = S { name; var }
let dot e f = EDot (e, f)
let access e k = EAccess (e, k)
let call f args = ECall (f, args)
let fun_ params body = EFun (params, body, false)
let table fields = ETable fields

let bin op a b = EBin (op, a, b)
let un op e = EUn (op, e)
let var i = EVar i
let int_ n = ENum (string_of_int n)
let string_ s = EStr s
let bool_ b = EBool b
let nil = ENil

let var_decl bindings =
  let ids, exps = List.split bindings in
  Local (ids, exps)

let assign lhs rhs = Assign (lhs, rhs)

let compare_ident a b =
  match a, b with
  | S { name = n1; _ }, S { name = n2; _ } -> String.compare n1 n2
  | S _, V _ -> -1
  | V _, S _ -> 1
  | V v1, V v2 -> Code.Var.compare v1 v2

let ident_equal a b = compare_ident a b = 0
