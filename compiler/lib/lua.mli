(** Lua 5.1 AST for lua_of_ocaml code generation. *)

module Code = Js_of_ocaml_compiler.Code

(** Lua identifiers. Either named (S) or a compiler variable (V). *)
type ident =
  | S of ident_string
  | V of Code.Var.t

and ident_string =
  { name : string
  ; var : Code.Var.t option
  }

(** Binary operators *)
type binop =
  | Add | Sub | Mul | Div | Mod | Pow
  | Concat
  | Eq | Neq | Lt | Le | Gt | Ge
  | And | Or

(** Unary operators *)
type unop =
  | Neg | Not | Len

(** Expressions *)
type expression =
  | ENil
  | EBool of bool
  | EStr of string
  | EVar of ident
  | ENum of string
  | ETable of table_field list
  | EFun of ident list * block * bool  (** params, body, variadic *)
  | ECall of expression * expression list
  | EMethod of expression * string * expression list
  | EBin of binop * expression * expression
  | EUn of unop * expression
  | EAccess of expression * expression
  | EDot of expression * string

(** Table constructor fields *)
and table_field =
  | TField of string * expression
  | TArray of expression

(** Block: a list of statements *)
and block = statement list

(** Statements *)
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

(** {2 Constructors} *)

val ident : ?var:Code.Var.t -> string -> ident
val dot : expression -> string -> expression
val access : expression -> expression -> expression
val call : expression -> expression list -> expression
val fun_ : ident list -> block -> expression
val table : table_field list -> expression
val bin : binop -> expression -> expression -> expression
val un : unop -> expression -> expression
val var : ident -> expression
val int_ : int -> expression
val string_ : string -> expression
val bool_ : bool -> expression
val nil : expression

(** Local variable declaration with initializers *)
val var_decl : (ident * expression) list -> statement

(** Assign to expressions *)
val assign : expression list -> expression list -> statement

(** {2 Ident utilities} *)
val is_ident : string -> bool
val compare_ident : ident -> ident -> int
val ident_equal : ident -> ident -> bool
