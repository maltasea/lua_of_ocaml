(** Translate Code.program (jsoo IR) into Lua.program. *)

open Js_of_ocaml_compiler.Stdlib
module L = Lua
module Code = Js_of_ocaml_compiler.Code
module Targetint = Js_of_ocaml_compiler.Targetint

(* ---- Variable naming ---- *)

let lua_safe_name s =
  let buf = Buffer.create (String.length s) in
  String.iter s ~f:(fun c ->
      match c with
      | 'a'..'z' | 'A'..'Z' | '0'..'9' | '_' -> Buffer.add_char buf c
      | _ -> Buffer.add_char buf '_');
  let s = Buffer.contents buf in
  if String.length s = 0 then "x"
  else if Char.is_digit s.[0] then "_" ^ s
  else s

let var_name v =
  match Code.Var.get_name v with
  | Some n ->
      let s = lua_safe_name n in
      if String.length s = 0
      then Printf.sprintf "_v%d" (Code.Var.idx v)
      else Printf.sprintf "%s_%d" s (Code.Var.idx v)
  | None -> Printf.sprintf "_v%d" (Code.Var.idx v)

let ident_of_var v = L.S { name = var_name v; var = Some v }
let evar v = L.EVar (ident_of_var v)

(* ---- Helper expressions ---- *)

let one = L.int_ 1
let two = L.int_ 2

(* Block field access: Lua 1-based, plus 1 for tag slot at index 1.
   So field n is at position n+2 in the Lua table. *)
let block_field e n = L.access e (L.int_ (n + 2))

(* Tag is always at position 1 *)
let block_tag e = L.access e (L.int_ 1)

(* is_block: type(x) ~= "number" *)
let is_block e =
  let type_call = L.call (L.EVar (L.ident "type")) [e] in
  L.bin L.Neq type_call (L.string_ "number")

(* is_int: type(x) == "number" *)
let is_int e =
  let type_call = L.call (L.EVar (L.ident "type")) [e] in
  L.bin L.Eq type_call (L.string_ "number")

(* OCaml int to Lua: shift right by 1 (arithmetic)
   In Lua, we use math.floor(n / 2) or (n // 2) but Lua 5.1 doesn't have //.
   We use math.floor(n / 2) for unwrap.
   For tag test, we check type(x) == "number"
   For operations on tagged ints:
     add: a + b (since both are shifted, (2a + 2b) = 2(a+b), no adjustment needed)
     sub: a - b (same logic)
     mul: (a // 2) * b (unwrap one operand to avoid double shift)
     div: (a // 2) // (b // 2) * 2
*)

let int_add a b = L.bin L.Add a b
let int_sub a b = L.bin L.Sub a b

let int_mul a b =
  (* a * b / 2 -- unwrap the double shift *)
  let floor = L.EVar (L.ident "math_floor") in
  let prod = L.bin L.Mul a b in
  L.call floor [L.bin L.Div prod two]

let int_div a b =
  (* (a / 2) / (b / 2) * 2... actually:
     In jsoo, div works on tagged ints. The formula is:
     (a >> 1) / (b >> 1) << 1
     In Lua: let a2 = floor(a/2), b2 = floor(b/2), then floor(a2/b2) * 2
  *)
  let floor = L.EVar (L.ident "math_floor") in
  let a2 = L.call floor [L.bin L.Div a two] in
  let b2 = L.call floor [L.bin L.Div b two] in
  L.bin L.Mul (L.call floor [L.bin L.Div a2 b2]) two

let int_mod a b =
  (* In jsoo: a % b, where both are tagged.
     Lua's % works on floats, so we need:
     let a2 = floor(a/2), b2 = floor(b/2)
     a2 % b2 * 2 + (a2 % b2 < 0 ? b2 * 2 : 0)
  *)
  let floor = L.EVar (L.ident "math_floor") in
  let a2 = L.call floor [L.bin L.Div a two] in
  let b2 = L.call floor [L.bin L.Div b two] in
  let mod_val = L.bin L.Mod a2 b2 in
  (* ensure positive *)
  let adjust = L.bin L.Mul two b2 in
  L.bin L.Add (L.bin L.Mul mod_val two)
    (L.ECall (L.EVar (L.ident "caml_mod_adjust"), [mod_val; adjust]))

let int_and a b =
  (* Lua 5.1 has no bitwise ops. Use math.floor(a/2) to untag, then we'd need
     bit32 library. For MVP, use a runtime function. *)
  let f = L.EVar (L.ident "caml_and") in
  L.call f [a; b]

let int_or a b =
  let f = L.EVar (L.ident "caml_or") in
  L.call f [a; b]

let int_xor a b =
  let f = L.EVar (L.ident "caml_xor") in
  L.call f [a; b]

let int_lsl a b =
  let f = L.EVar (L.ident "caml_lsl") in
  L.call f [a; b]

let int_lsr a b =
  let f = L.EVar (L.ident "caml_lsr") in
  L.call f [a; b]

let int_asr a b =
  let f = L.EVar (L.ident "caml_asr") in
  L.call f [a; b]

(* ---- Integer comparison on tagged ints ---- *)

let int_eq a b = L.bin L.Eq a b
let int_ne a b = L.bin L.Neq a b
let int_lt a b = L.bin L.Lt a b
let int_le a b = L.bin L.Le a b
let int_gt a b = L.bin L.Gt a b
let int_ge a b = L.bin L.Ge a b

(* ---- Globals ---- *)

let global_data = L.EVar (L.ident "caml_global_data")
let global_get idx = L.access global_data (L.int_ (idx + 1))
let global_set idx e = L.assign [L.access global_data (L.int_ (idx + 1))] [e]

(* ---- Block construction ---- *)

let make_block tag fields =
  let tag = L.TArray tag in
  let fields = List.map fields ~f:(fun e -> L.TArray e) in
  L.table (tag :: fields)

(* ---- String representation ----
   OCaml strings: in jsoo, strings are JS strings. In Lua, strings are native.
   We pass through directly for now. *)

(* ---- Constant translation ---- *)

let rec translate_constant = function
  | Code.String s -> L.string_ s
  | Code.NativeString (Code.Native_string.Byte s) -> L.string_ s
  | Code.NativeString _ -> L.string_ ""
  | Code.Int i ->
      let n = Int32.(to_int (shift_left (Targetint.to_int32 i) 1)) in
      L.int_ n
  | Code.Int32 i ->
      let n = Int32.(to_int (shift_left i 1)) in
      L.int_ n
  | Code.NativeInt i ->
      let n = Int32.(to_int (shift_left i 1)) in
      L.int_ n
  | Code.Float _f ->
      make_block (L.int_ 253) [L.int_ 0]
  | Code.Tuple (tag, fields, _) ->
      let tag = L.int_ tag in
      let fields = Array.to_list (Array.map fields ~f:translate_constant) in
      make_block tag fields
  | Code.Float_array _ ->
      make_block (L.int_ 253) [L.int_ 0]
  | Code.Int64 _ ->
      L.int_ 0

(* ---- Expression translation ---- *)

let rec translate_expr = function
  | Code.Apply { f; args; _ } ->
      let fn = evar f in
      let args = List.map args ~f:evar in
      L.call fn args
  | Code.Block (tag, fields, _, _) ->
      let tag = L.int_ tag in
      let fields = Array.to_list (Array.map fields ~f:evar) in
      make_block tag fields
  | Code.Field (x, n, _) ->
      block_field (evar x) n
  | Code.Closure (params, (pc, _), _) ->
      (* We need to compile the closure body *)
      compile_closure_expr (pc, params) params
  | Code.Constant c ->
      translate_constant c
  | Code.Prim (p, args) ->
      translate_prim p args
  | Code.Special (Code.Alias_prim name) ->
      L.EVar (L.ident name)

and translate_prim p args =
  let prim_to_val a = match a with Code.Pv v -> evar v | Code.Pc c -> translate_constant c in
  match p, args with
  | Code.Vectlength, [a] ->
      L.bin L.Sub (L.EUn (L.Len, prim_to_val a)) one
  | Code.Array_get, [a; b] ->
      L.access (prim_to_val a) (L.bin L.Add (prim_to_val b) one)
  | Code.Not, [a] ->
      L.EUn (L.Not, prim_to_val a)
  | Code.IsInt, [a] ->
      is_int (prim_to_val a)
  | Code.Eq, [a; b] ->
      int_eq (prim_to_val a) (prim_to_val b)
  | Code.Neq, [a; b] ->
      int_ne (prim_to_val a) (prim_to_val b)
  | Code.Lt, [a; b] ->
      int_lt (prim_to_val a) (prim_to_val b)
  | Code.Le, [a; b] ->
      int_le (prim_to_val a) (prim_to_val b)
  | Code.Ult, [a; b] ->
      int_lt (prim_to_val a) (prim_to_val b)
  | Code.Extern name, args ->
      let name = if String.length name > 0 && Char.equal name.[0] '%'
        then String.sub name ~pos:1 ~len:(String.length name - 1)
        else name
      in
      L.call (L.EVar (L.ident name)) (List.map args ~f:prim_to_val)
  | _ ->
      let name = match p with
        | Code.Extern s -> s
        | _ -> "caml_prim"
      in
      let name = if String.length name > 0 && Char.equal name.[0] '%'
        then String.sub name ~pos:1 ~len:(String.length name - 1)
        else name
      in
      L.call (L.EVar (L.ident name)) (List.map args ~f:prim_to_val)

(* ---- Closure compilation ----
   We compile closures lazily: when we encounter a Closure expression,
   we need to generate the function. To handle this, we pre-scan the program
   for all closure entry points and compile them as local functions. *)

and compile_closure_expr (pc, closure_args) _params =
  (* For now, create a simple function wrapper.
     The actual closure compilation happens in compile_program
     where we have access to all blocks. *)
  let block_name = Printf.sprintf "_block_%d" (pc : Code.Addr.t :> int) in
  let f = L.EVar (L.ident block_name) in
  (* Return a function that calls the block with bound args *)
  L.EFun (List.map closure_args ~f:ident_of_var, [
    L.Return [L.call f (List.map closure_args ~f:evar)]
  ], false)

(* ---- Instruction translation ---- *)

let translate_instr = function
  | Code.Let (x, e) ->
      let rhs = translate_expr e in
      let id = ident_of_var x in
      [L.Assign ([L.EVar id], [rhs])]
  | Code.Assign (x, y) ->
      [L.Assign ([evar x], [evar y])]
  | Code.Set_field (x, n, _, y) ->
      [L.Assign ([block_field (evar x) n], [evar y])]
  | Code.Offset_ref (x, n) ->
      let field = block_field (evar x) 0 in
      let rhs = match n with
        | 1 -> L.bin L.Add field one
        | -1 -> L.bin L.Sub field one
        | n when n < 0 -> L.bin L.Sub field (L.int_ (-n))
        | _ -> L.bin L.Add field (L.int_ n)
      in
      [L.Assign ([block_field (evar x) 0], [rhs])]
  | Code.Array_set (x, y, z) ->
      [L.Assign ([L.access (evar x) (L.bin L.Add (evar y) one)], [evar z])]
  | Code.Event _ -> []

(* ---- Control flow / last instruction translation ---- *)

let translate_last _blocks = function
  | Code.Return x -> [L.Return [evar x]]
  | Code.Raise (x, _) ->
      (* Lua error() for exceptions *)
      [L.ExprStmt (L.call (L.EVar (L.ident "error")) [evar x])]
  | Code.Stop -> [L.Return []]
  | Code.Branch (pc, args) ->
      let block_name = Printf.sprintf "_block_%d" (pc : Code.Addr.t :> int) in
      [L.Return [L.call (L.EVar (L.ident block_name)) (List.map args ~f:evar)]]
  | Code.Cond (x, (pc1, args1), (pc2, args2)) ->
      let block1 = Printf.sprintf "_block_%d" (pc1 : Code.Addr.t :> int) in
      let block2 = Printf.sprintf "_block_%d" (pc2 : Code.Addr.t :> int) in
      let call1 = L.call (L.EVar (L.ident block1)) (List.map args1 ~f:evar) in
      let call2 = L.call (L.EVar (L.ident block2)) (List.map args2 ~f:evar) in
      [L.If (evar x,
              [L.Return [call1]],
              [],
              Some [L.Return [call2]])]
  | Code.Switch (x, cases) ->
      let n = Array.length cases in
      if n = 0 then [L.Return []]
      else
        let rec build_if i =
          if i >= n then None
          else
            let (pc, args) = cases.(i) in
            let block = Printf.sprintf "_block_%d" (pc : Code.Addr.t :> int) in
            let cond = L.bin L.Eq (evar x) (L.int_ i) in
            let then_body = [L.Return [L.call (L.EVar (L.ident block)) (List.map args ~f:evar)]] in
            let else_body = build_if (i + 1) in
            Some [L.If (cond, then_body, [], else_body)]
        in
        (match build_if 0 with Some s -> s | None -> [L.Return []])
  | Code.Pushtrap ((pc_handler, handler_args), _x, (pc_cont, cont_args)) ->
      (* pcall wrapper: wrap continuation in pcall *)
      let handler_block = Printf.sprintf "_block_%d" (pc_handler : Code.Addr.t :> int) in
      let cont_block = Printf.sprintf "_block_%d" (pc_cont : Code.Addr.t :> int) in
      let ok_var = L.ident "ok" in
      let res_var = L.ident "res" in
      [L.Local ([ok_var; res_var],
                [L.call (L.EVar (L.ident "pcall"))
                   [L.EFun ([], [
                     L.Return [L.call (L.EVar (L.ident cont_block))
                                 (List.map cont_args ~f:evar)]
                   ], false)]]);
       L.If (L.EVar ok_var,
             [L.Return [L.EVar res_var]],
             [],
             Some [L.Return [L.call (L.EVar (L.ident handler_block))
                               (L.EVar res_var :: List.map handler_args ~f:evar)]])]
  | Code.Poptrap _ ->
      (* After poptrap, we just continue. The pcall already handled the exception. *)
      []

(* ---- Block compilation ---- *)

let compile_block_def (pc : Code.Addr.t) (block : Code.block) =
  let body_stmts = List.concat_map block.body ~f:translate_instr in
  let last_stmts = translate_last block.body block.branch in
  let all_stmts = body_stmts @ last_stmts in
  let block_name = Printf.sprintf "_block_%d" (pc :> int) in
  let params = List.map block.params ~f:ident_of_var in
  L.Assign ([L.EVar (L.ident block_name)], [L.fun_ params all_stmts])

(* ---- Program compilation ---- *)

let compile_program (p : Code.program) =
  (* Collect all blocks reachable from any closure *)
  let block_order = ref [] in
  let visited = ref Code.Addr.Set.empty in
  let rec visit pc =
    if Code.Addr.Set.mem pc !visited then ()
    else (
      visited := Code.Addr.Set.add pc !visited;
      block_order := pc :: !block_order;
      let block = Code.Addr.Map.find pc p.blocks in
      (* Visit blocks reachable from instructions (closures) *)
      List.iter block.body ~f:(fun instr ->
          match instr with
          | Code.Let (_, Code.Closure (_, (pc', _), _)) ->
              if Code.Addr.Map.mem pc' p.blocks then visit pc'
          | _ -> ());
      (* Follow control flow *)
      match block.branch with
      | Code.Branch (pc', _) -> visit pc'
      | Code.Cond (_, (pc1, _), (pc2, _)) -> visit pc1; visit pc2
      | Code.Switch (_, cases) ->
          Array.iter cases ~f:(fun (pc', _) -> visit pc')
      | Code.Pushtrap ((pc_h, _), _, (pc_c, _)) -> visit pc_h; visit pc_c
      | Code.Poptrap _ -> ()
      | Code.Return _ | Code.Raise _ | Code.Stop -> ())
  in
  visit p.start;

  (* Forward-declare all block functions as nil for mutual recursion *)
  let forward_decls = List.rev_map !block_order ~f:(fun pc ->
      let name = Printf.sprintf "_block_%d" (pc :> int) in
      L.Assign ([L.EVar (L.ident name)], [L.nil]))
  in

  (* Compile all reachable blocks as function definitions *)
  let block_defs = List.rev_map !block_order ~f:(fun pc ->
      let block = Code.Addr.Map.find pc p.blocks in
      compile_block_def pc block)
  in

  (* The entry point calls the start block *)
  let start_block = Printf.sprintf "_block_%d" (p.start :> int) in
  let entry_call = L.ExprStmt (L.call (L.EVar (L.ident start_block)) []) in

  forward_decls @ block_defs @ [entry_call]
