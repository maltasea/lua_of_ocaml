(** Pretty-printer for the Lua 5.1 AST. *)

open Js_of_ocaml_compiler.Stdlib
module L = Lua
module PP = Js_of_ocaml_compiler.Pretty_print
module Code = Js_of_ocaml_compiler.Code

let lua_keywords =
  [ "and"; "break"; "do"; "else"; "elseif"; "end"; "false"; "for"
  ; "function"; "if"; "in"; "local"; "nil"; "not"; "or"; "repeat"
  ; "return"; "then"; "true"; "until"; "while"
  ]

let is_keyword s = List.mem ~eq:String.equal s lua_keywords

(* ---- Identifier printing ---- *)

let pp_ident f id =
  match id with
  | L.V v -> (
      match Code.Var.get_name v with
      | Some n when L.is_ident n && not (is_keyword n) -> PP.string f n
      | _ -> PP.string f (Printf.sprintf "_v%d" (Code.Var.idx v)))
  | L.S { name; _ } ->
      if is_keyword name
      then PP.string f (name ^ "_")  (* mangle keywords *)
      else PP.string f name

(* ---- Expression printing ---- *)

let rec protect level f e =
  if prec e > level then expression f e else paren_expression f e

and prec = function
  | L.ENil | L.EBool _ | L.ENum _ | L.EStr _ | L.EVar _ | L.ETable _ | L.EFun _ -> 12
  | L.EAccess _ | L.EDot _ | L.ECall _ | L.EMethod _ -> 11
  | L.EBin (Pow, _, _) -> 10
  | L.EUn (_, _) -> 9
  | L.EBin ((Mul | Div | Mod), _, _) -> 8
  | L.EBin ((Add | Sub), _, _) -> 7
  | L.EBin (Concat, _, _) -> 6
  | L.EBin ((Lt | Le | Gt | Ge | Eq | Neq), _, _) -> 5
  | L.EBin (And, _, _) -> 4
  | L.EBin (Or, _, _) -> 3

and expression f e =
  match e with
  | L.ENil -> PP.string f "nil"
  | L.EBool true -> PP.string f "true"
  | L.EBool false -> PP.string f "false"
  | L.ENum s -> PP.string f s
  | L.EStr s ->
      PP.string f "\"";
      String.iter s ~f:(fun c ->
          match c with
          | '"' -> PP.string f "\\\""
          | '\\' -> PP.string f "\\\\"
          | '\n' -> PP.string f "\\n"
          | '\t' -> PP.string f "\\t"
          | '\r' -> PP.string f "\\r"
          | '\000'..'\031' ->
              PP.string f (Printf.sprintf "\\%03d" (Char.code c))
          | _ -> PP.string f (Printf.sprintf "%c" c));
      PP.string f "\""
  | L.EVar v -> pp_ident f v
  | L.ETable fields -> table_constructor f fields
  | L.EFun (params, body, _variadic) -> function_literal f params body
  | L.ECall (fn, args) ->
      expression f fn;
      PP.string f "(";
      comma_list f expression args;
      PP.string f ")"
  | L.EMethod (obj, name, args) ->
      protect 10 f obj;
      PP.string f ":";
      PP.string f name;
      PP.string f "(";
      comma_list f expression args;
      PP.string f ")"
  | L.EBin (op, a, b) ->
      protect (prec e) f a;
      PP.string f " ";
      PP.string f (binop_str op);
      PP.string f " ";
      protect (prec e) f b
  | L.EUn (op, a) ->
      PP.string f (unop_str op);
      protect (prec e) f a
  | L.EAccess (tbl, key) ->
      protect 10 f tbl;
      PP.string f "[";
      expression f key;
      PP.string f "]"
  | L.EDot (tbl, field) ->
      protect 10 f tbl;
      PP.string f ".";
      PP.string f field

and paren_expression f e =
  PP.string f "(";
  expression f e;
  PP.string f ")"

and table_constructor f fields =
  match fields with
  | [] -> PP.string f "{}"
  | _ ->
      PP.string f "{";
      let rec aux first = function
        | [] -> ()
        | L.TArray e :: rest ->
            if not first then PP.string f ", ";
            expression f e;
            aux false rest
        | L.TField (name, e) :: rest ->
            if not first then PP.string f ", ";
            if L.is_ident name
            then PP.string f name
            else (PP.string f "[\""; PP.string f name; PP.string f "\"]");
            PP.string f " = ";
            expression f e;
            aux false rest
      in
      aux true fields;
      PP.string f "}"

and function_literal f params body =
  PP.string f "function(";
  comma_list_ident f params;
  PP.string f ") ";
  statement_list f body;
  PP.string f "end"

and comma_list_ident f items =
  let rec aux first = function
    | [] -> ()
    | [x] -> if not first then PP.string f ", "; pp_ident f x
    | x :: rest ->
        if not first then PP.string f ", ";
        pp_ident f x;
        aux false rest
  in
  aux true items

and comma_list f pp items =
  let rec aux first = function
    | [] -> ()
    | [x] -> if not first then PP.string f ", "; pp f x
    | x :: rest ->
        if not first then PP.string f ", ";
        pp f x;
        aux false rest
  in
  aux true items

and binop_str = function
  | L.Add -> "+" | L.Sub -> "-" | L.Mul -> "*" | L.Div -> "/" | L.Mod -> "%"
  | L.Pow -> "^" | L.Concat -> ".."
  | L.Eq -> "==" | L.Neq -> "~=" | L.Lt -> "<" | L.Le -> "<="
  | L.Gt -> ">" | L.Ge -> ">=" | L.And -> "and" | L.Or -> "or"

and unop_str = function
  | L.Neg -> "-" | L.Not -> "not " | L.Len -> "#"

(* ---- Statement printing ---- *)

and statement f st =
  match st with
  | L.Comment s ->
      PP.string f "-- ";
      PP.string f s;
      PP.newline f
  | L.ExprStmt e ->
      expression f e;
      PP.newline f
  | L.Return [] ->
      PP.string f "return";
      PP.newline f
  | L.Return es ->
      PP.string f "return ";
      comma_list f expression es;
      PP.newline f
  | L.Break ->
      PP.string f "break";
      PP.newline f
  | L.Block ss ->
      PP.string f "do ";
      statement_list f ss;
      PP.string f " end";
      PP.newline f
  | L.Local ([id], es) ->
      PP.string f "local ";
      pp_ident f id;
      (match es with
       | [] -> ()
       | _ ->
           PP.string f " = ";
           comma_list f expression es);
      PP.newline f
  | L.Local (ids, es) ->
      PP.string f "local ";
      comma_list_ident f ids;
      if not (List.is_empty es)
      then (PP.string f " = "; comma_list f expression es);
      PP.newline f
  | L.LocalFun (id, params, body) ->
      PP.string f "local function ";
      pp_ident f id;
      PP.string f "(";
      comma_list_ident f params;
      PP.string f ") ";
      statement_list f body;
      PP.string f " end";
      PP.newline f
  | L.Assign (lhs, rhs) ->
      comma_list f expression lhs;
      PP.string f " = ";
      comma_list f expression rhs;
      PP.newline f
  | L.FunAssign (lhs, params, body) ->
      expression f lhs;
      if List.is_empty params then PP.string f " = function() "
      else (
        PP.string f " = function(";
        comma_list_ident f params;
        PP.string f ") ");
      statement_list f body;
      PP.string f " end";
      PP.newline f
  | L.If (cond, then_body, elseif_clauses, else_body) ->
      PP.string f "if ";
      expression f cond;
      PP.string f " then";
      PP.newline f;
      statement_list f then_body;
      (match elseif_clauses with
       | [] -> ()
       | _ ->
           List.iter elseif_clauses ~f:(fun (c, b) ->
               PP.string f "elseif ";
               expression f c;
               PP.string f " then";
               PP.newline f;
               statement_list f b));
      (match else_body with
       | None -> ()
       | Some b ->
           PP.string f "else";
           PP.newline f;
           statement_list f b);
      PP.string f "end";
      PP.newline f
  | L.While (cond, body) ->
      PP.string f "while ";
      expression f cond;
      PP.string f " do";
      PP.newline f;
      statement_list f body;
      PP.string f "end";
      PP.newline f
  | L.Repeat (body, cond) ->
      PP.string f "repeat";
      PP.newline f;
      statement_list f body;
      PP.string f "until ";
      expression f cond;
      PP.newline f
  | L.ForRange (var, start, stop, step, body) ->
      PP.string f "for ";
      pp_ident f var;
      PP.string f " = ";
      expression f start;
      PP.string f ", ";
      expression f stop;
      (match step with
       | None -> ()
       | Some s ->
           PP.string f ", ";
           expression f s);
      PP.string f " do";
      PP.newline f;
      statement_list f body;
      PP.string f "end";
      PP.newline f
  | L.ForIn (vars, exps, body) ->
      PP.string f "for ";
      comma_list_ident f vars;
      PP.string f " in ";
      comma_list f expression exps;
      PP.string f " do";
      PP.newline f;
      statement_list f body;
      PP.string f "end";
      PP.newline f

and statement_list f stmts =
  List.iter stmts ~f:(statement f)

and program f stmts =
  statement_list f stmts
