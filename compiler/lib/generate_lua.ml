(** Translate Code.program (jsoo IR) into Lua.program.
    Uses structural CFG analysis like js_of_ocaml's generate.ml. *)

open Js_of_ocaml_compiler.Stdlib
module L = Lua
module Code = Js_of_ocaml_compiler.Code
module Targetint = Js_of_ocaml_compiler.Targetint
module Structure = Js_of_ocaml_compiler.Structure

(* ---- Unsupported-feature tracking ----
   Int64 and Float_array currently lower to placeholders (0 / empty block).
   Track how many we emit so the CLI can warn the user. *)
let unsupported_int64_count = ref 0
let unsupported_float_array_count = ref 0

let reset_unsupported_counts () =
  unsupported_int64_count := 0;
  unsupported_float_array_count := 0

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
      Printf.sprintf "%s_%d" s (Code.Var.idx v)
  | None -> Printf.sprintf "_v%d" (Code.Var.idx v)

let ident_of_var v = L.S { name = var_name v; var = Some v }
let evar v = L.EVar (ident_of_var v)
let var_str v = var_name v
let one = L.int_ 1
let two = L.int_ 2
let block_field e n = L.access e (L.int_ (n + 2))
let make_block tag fields =
  L.table (L.TArray tag :: List.map fields ~f:(fun f -> L.TArray f))

(* ---- Helpers ---- *)

let get_params (b : Js_of_ocaml_compiler.Code.block) = b.params
let get_body (b : Js_of_ocaml_compiler.Code.block) = b.body
let get_branch (b : Js_of_ocaml_compiler.Code.block) = b.branch

let clean_extern name =
  if String.length name > 0 && Char.equal name.[0] '%'
  then String.sub name ~pos:1 ~len:(String.length name - 1)
  else name

let bind_args tgt_params arg_vars =
  if List.length tgt_params = List.length arg_vars
  then List.map2 tgt_params arg_vars ~f:(fun p a -> L.Assign ([evar p], [evar a]))
  else []

(* ---- Scope stack ---- *)

type edge_kind = Loop | Exit_loop | Forward

(* ---- Constant translation ---- *)

let rec translate_expr blocks = function
  | Code.Apply { f; args; _ } ->
      L.call (evar f) (List.map ~f:evar args)
  | Code.Block (tag, fields, _, _) ->
      make_block (L.int_ tag) (Array.to_list (Array.map ~f:evar fields))
  | Code.Field (x, n, _) -> block_field (evar x) n
  | Code.Closure (params, (pc, _), cloc) ->
      let params' = List.map params ~f:ident_of_var in
      let body = compile_closure blocks pc in
      let body = match cloc with
        | Some pi ->
            let file = match pi.src with
              | Some f -> Filename.basename f
              | None -> "?"
            in
            L.Comment (Printf.sprintf "# %s:%d" file pi.line) :: body
        | None -> body
      in
      L.EFun (params', body, false)
  | Code.Constant c -> translate_constant c
  | Code.Prim (p, args) -> translate_prim p args
  | Code.Special (Code.Alias_prim name) ->
      L.EVar (L.ident (clean_extern name))

and translate_constant = function
  | Code.String s -> L.string_ s
  | Code.NativeString (Code.Native_string.Byte s) -> L.string_ s
  | Code.NativeString _ -> L.string_ ""
  | Code.Int i ->
      let n = Targetint.(shift_left i 1 |> to_int_exn) in
      L.int_ n
  | Code.Int32 i ->
      let n = Int32.(to_int (shift_left i 1)) in
      L.int_ n
  | Code.NativeInt i ->
      let n = Int32.(to_int (shift_left i 1)) in
      L.int_ n
  | Code.Float f ->
      let bits = Int64.float_of_bits f in
      L.table [L.TArray (L.int_ 253); L.TArray (L.ENum (Printf.sprintf "%.17g" bits))]
  | Code.Tuple (tag, fields, _) ->
      let fields = Array.to_list (Array.map fields ~f:translate_constant) in
      make_block (L.int_ tag) fields
  | Code.Float_array _ ->
      incr unsupported_float_array_count;
      make_block (L.int_ 253) [L.int_ 0]
  | Code.Int64 _ ->
      incr unsupported_int64_count;
      L.int_ 0

and translate_prim p args =
  let pa a = match a with Code.Pv v -> evar v | Code.Pc c -> translate_constant c in
  match p, args with
  | Code.Vectlength, [a] ->
      L.bin L.Mul (L.bin L.Sub (L.EUn (L.Len, pa a)) one) two
  | Code.Array_get, [a; b] ->
      L.access (pa a) (L.bin L.Add (L.bin L.Div (pa b) two) two)
  | Code.Not, [a] ->
      (* OCaml bool false = 0 (truthy in Lua), so "not a" gives wrong result.
         Emit (a == 0 or a == false) — true iff a is OCaml-false or Lua-false. *)
      L.bin L.Or (L.bin L.Eq (pa a) (L.int_ 0)) (L.bin L.Eq (pa a) (L.EBool false))
  | Code.IsInt, [a] ->
      L.bin L.Eq (L.call (L.EVar (L.ident "type")) [pa a]) (L.string_ "number")
  | Code.Eq, [a; b] -> L.bin L.Eq (pa a) (pa b)
  | Code.Neq, [a; b] -> L.bin L.Neq (pa a) (pa b)
  | Code.Lt, [a; b] -> L.bin L.Lt (pa a) (pa b)
  | Code.Le, [a; b] -> L.bin L.Le (pa a) (pa b)
  | Code.Ult, [a; b] -> L.bin L.Lt (pa a) (pa b)
  | Code.Extern name, args ->
      L.call (L.EVar (L.ident (clean_extern name))) (List.map ~f:pa args)
  | _ ->
      L.call (L.EVar (L.ident "caml_prim_missing")) (List.map ~f:pa args)

(* ---- Translate instructions ---- *)

and translate_instr blocks = function
  | Code.Let (x, e) -> [L.Assign ([evar x], [translate_expr blocks e])]
  | Code.Assign (x, y) -> [L.Assign ([evar x], [evar y])]
  | Code.Set_field (x, n, _, y) ->
      [L.Assign ([block_field (evar x) n], [evar y])]
  | Code.Offset_ref (x, n) ->
      (* OCaml ints are encoded as 2*v, so incrementing by n must add 2*n. *)
      let f = block_field (evar x) 0 in
      let rhs = match n with
        | 0 -> f
        | n when n < 0 -> L.bin L.Sub f (L.int_ (-2 * n))
        | _ -> L.bin L.Add f (L.int_ (2 * n))
      in
      [L.Assign ([block_field (evar x) 0], [rhs])]
  | Code.Array_set (x, y, z) ->
      [L.Assign ([L.access (evar x) (L.bin L.Add (evar y) one)], [evar z])]
  | Code.Event pi ->
      let file = match pi.src with
        | Some f -> Filename.basename f
        | None -> "?"
      in
      [L.Comment (Printf.sprintf "# %s:%d" file pi.line)]

(* ---- Scope stack for break/continue ---- *)

(* ---- Closure compilation ---- *)

and compile_closure blocks entry_pc =
  let structure = Structure.build_graph blocks entry_pc in
  let dom = Structure.dominator_tree structure in
  let visited_blocks = ref Code.Addr.Set.empty in

  (* Collect predecessor counts to identify merge nodes *)
  let pred_counts = ref Code.Addr.Map.empty in
  let incr_pred pc =
    pred_counts := Code.Addr.Map.update pc (fun n ->
        Some (Option.value ~default:0 n + 1)) !pred_counts
  in
  let _ = Code.Addr.Map.fold (fun _pc block () ->
      let add_target = function
        | pc' -> incr_pred pc'
      in
      (match get_branch block with
       | Code.Branch (pc', _) -> add_target pc'
       | Code.Cond (_, (pc1, _), (pc2, _)) -> add_target pc1; add_target pc2
       | Code.Switch (_, cases) -> Array.iter ~f:(fun (pc', _) -> add_target pc') cases
       | Code.Pushtrap ((pc_h, _), _, (pc_c, _)) -> add_target pc_h; add_target pc_c
       | Code.Poptrap (pc, _) -> add_target pc
       | Code.Return _ | Code.Raise _ | Code.Stop -> ());
       ()) blocks () in

  (* Precompile merge blocks (>1 predecessor) as functions, but only for
     small CFGs — the recursive inlining inside each merge's body blows up
     superlinearly on big programs and can hang the compiler.  Merge funcs
     are emitted as global assignments so the 200-locals-per-function limit
     never bites. *)
  let merge_blocks = ref Code.Addr.Set.empty in
  (if Code.Addr.Map.cardinal blocks < 500 then
     let _ = Code.Addr.Map.fold (fun pc n () ->
         if n > 1 then merge_blocks := Code.Addr.Set.add pc !merge_blocks;
         ()) !pred_counts () in ());

  let merge_name pc = Printf.sprintf "_m%d" (pc :> int) in

  let merge_decls = ref [] in
  let merge_defs = ref [] in
  let merge_compiled = ref Code.Addr.Set.empty in

  let compile_merge pc =
    if Code.Addr.Set.mem pc !merge_blocks
       && not (Code.Addr.Set.mem pc !merge_compiled)
    then (
      merge_compiled := Code.Addr.Set.add pc !merge_compiled;
      let block = Code.Addr.Map.find pc blocks in
      let body =
        List.concat_map ~f:(translate_instr blocks) (get_body block)
        @ compile_conditional ~fall_through:None structure dom visited_blocks
            blocks merge_blocks (Some pc) [] (get_branch block)
      in
      (* Globals: no `local` declaration; just assign. *)
      merge_defs := L.Assign ([L.EVar (L.ident (merge_name pc))],
                               [L.fun_ (List.map ~f:ident_of_var (get_params block)) body])
                    :: !merge_defs)
  in

  let _ = Code.Addr.Set.fold (fun pc () -> compile_merge pc; ()) !merge_blocks () in

  let body = compile_branch ~fall_through:None structure dom visited_blocks
               blocks merge_blocks None (entry_pc, []) [] in

  List.rev !merge_decls @ List.rev !merge_defs @ body

(* ---- Branch: jump to a block ---- *)

and compile_branch ~fall_through structure dom visited_blocks
    blocks merge_blocks parent_block (pc, args) scope_stack =

  (* Check fall-through *)
  let is_fall_through = match fall_through with
    | Some ft -> ft = pc
    | None -> false
  in

  if is_fall_through then
    (* Sequential code, no jump needed *)
    bind_args (Code.Addr.Map.find pc blocks).params args
  else
    (* Check scope stack for break/continue *)
    let scope = List.find_map scope_stack ~f:(fun (pc', kind) ->
        if pc = pc' then Some kind else None)
    in
    match scope with
    | Some Loop ->
        (* Back-edge to loop header, just bind args and continue loop *)
        bind_args (Code.Addr.Map.find pc blocks).params args
    | Some Exit_loop ->
        (* Exit loop: break *)
        bind_args (Code.Addr.Map.find pc blocks).params args
        @ [L.Break]
    | Some Forward ->
        (* Forward edge already compiled, just bind args *)
        bind_args (Code.Addr.Map.find pc blocks).params args
        @ [L.Break]
    | None when Code.Addr.Set.mem pc !merge_blocks ->
        (* Merge node with multiple predecessors: call the precompiled function *)
        let args' = List.map ~f:evar args in
        [L.Return [L.call (L.EVar (L.ident (Printf.sprintf "_m%d" (pc :> int)))) args']]
    | None ->
        (* Block not in scope.  Bind the target block's formal params to the
           args passed by this branch BEFORE the body, then either inline it
           (first visit) or — if already visited — break out of the enclosing
           loop so control reaches the post-loop code. *)
        let target_params = (Code.Addr.Map.find pc blocks).params in
        let arg_binds = bind_args target_params args in
        let already_visited = Code.Addr.Set.mem pc !visited_blocks in
        let in_loop =
          List.exists scope_stack ~f:(fun (_, k) ->
              match k with Loop -> true | _ -> false)
        in
        if already_visited && in_loop then
          arg_binds @ [L.Break]
        else
          arg_binds
          @ compile_block ~fall_through structure dom visited_blocks
              blocks merge_blocks parent_block pc scope_stack

(* ---- Block: loop detection ---- *)

and compile_block ~fall_through structure dom visited_blocks
    blocks merge_blocks parent_block pc scope_stack =

  if Code.Addr.Set.mem pc !visited_blocks then []
  else if (try Structure.is_loop_header structure pc with Not_found -> false) then (
    (* Loop detected! *)
    visited_blocks := Code.Addr.Set.add pc !visited_blocks;
    let block = Code.Addr.Map.find pc blocks in
    let scope_stack = (pc, Loop) :: scope_stack in
    let body =
      List.concat_map ~f:(translate_instr blocks) (get_body block)
      @ compile_conditional ~fall_through:(Some pc) structure dom visited_blocks
          blocks merge_blocks (Some pc) scope_stack (get_branch block)
    in
    [L.While (L.bool_ true, body)]
  ) else
    compile_block_no_loop ~fall_through structure dom visited_blocks
      blocks merge_blocks parent_block pc scope_stack

(* ---- Block no loop ---- *)

and compile_block_no_loop ~fall_through structure dom visited_blocks
    blocks merge_blocks _parent_block pc scope_stack =

  if Code.Addr.Set.mem pc !visited_blocks then []
  else (
    visited_blocks := Code.Addr.Set.add pc !visited_blocks;
    let block = Code.Addr.Map.find pc blocks in

    let instr_stmts = List.concat_map ~f:(translate_instr blocks) (get_body block) in

    let branch_stmts = compile_conditional ~fall_through structure dom visited_blocks
        blocks merge_blocks (Some pc) scope_stack (get_branch block)
    in

    instr_stmts @ branch_stmts
  )

(* ---- Conditional: handle the last instruction of a block ---- *)

and compile_conditional ~fall_through structure dom visited_blocks
    blocks merge_blocks parent_block scope_stack last =

  let branch ~fall_through pc args =
    compile_branch ~fall_through structure dom visited_blocks
      blocks merge_blocks parent_block (pc, args) scope_stack
  in

  match last with
  | Code.Return x -> [L.Return [evar x]]
  | Code.Raise (x, _) ->
      [L.ExprStmt (L.call (L.EVar (L.ident "caml_raise")) [evar x])]
  | Code.Stop -> [L.Return []]
  | Code.Branch (pc', args) ->
      branch ~fall_through pc' args

  | Code.Cond (x, (pc1, args1), (pc2, args2)) ->
      let body1 = branch ~fall_through pc1 args1 in
      let body2 = branch ~fall_through pc2 args2 in
      (* OCaml false is encoded as int 0 (truthy in Lua).  Also accept Lua
         booleans returned by externals (e.g. love2d lk_is_down). *)
      let cond =
        L.bin L.And
          (L.bin L.Neq (evar x) (L.int_ 0))
          (L.bin L.Neq (evar x) (L.EBool false))
      in
      [L.If (cond, body1, [], Some body2)]

  | Code.Switch (x, cases) ->
      (* Switch input is OCaml-encoded: int variants are 2*i, block tags come
         from %direct_obj_tag which we also return as 2*tag (see misc.lua).
         So all case indices i compare against 2*i. *)
      let n = Array.length cases in
      let rec build i =
        if i >= n then []
        else
          let (pc', args') = cases.(i) in
          let body = branch ~fall_through pc' args' in
          let cond = L.bin L.Eq (evar x) (L.int_ (2 * i)) in
          L.If (cond, body, [], None) :: build (i + 1)
      in
      build 0

  | Code.Pushtrap ((pc_h, args_h), x, (pc_c, args_c)) ->
      (* pcall-based try-catch: pc_h=continuation, pc_c=handler (swapped in IR) *)
      let body_c = branch ~fall_through pc_h args_h in
      let body_h = branch ~fall_through pc_c (x :: args_c) in
      let ok_var = L.ident "_ok" in
      let res_var = L.ident "_res" in
      [ L.Local ([ok_var; res_var],
                 [L.call (L.EVar (L.ident "pcall"))
                    [L.EFun ([], body_c, false)]])
      ; L.If (L.EVar ok_var,
              [L.Assign ([evar x], [L.EVar res_var])],
              [],
              Some (L.Assign ([evar x], [L.EVar (L.ident "_caml_exn")]) :: body_h))
      ]

  | Code.Poptrap _ ->
      (* After try/catch, x holds the result. Poptrap is implicit in JS/Lua.
         The corresponding Pushtrap already emitted the try/catch.
         We just continue to the next block (called by our caller). *)
      []

(* ---- Program compilation ---- *)

let compile_program (p : Code.program) =
  (* Collect all vars from all blocks, assign as globals.
     Using L.Local here would exceed Lua 5.1's 200-local limit for many
     programs.  Globals avoid that limit at the cost of scoping leakage. *)
  let var_set = ref Code.Var.Set.empty in
  let var_decls = ref [] in
  let _ = Code.Addr.Map.fold (fun _pc block () ->
      List.iter ~f:(fun v ->
          if not (Code.Var.Set.mem v !var_set) then (
            var_set := Code.Var.Set.add v !var_set;
            var_decls := L.Assign ([evar v], [L.nil]) :: !var_decls))
        (get_params block);
      List.iter ~f:(fun instr ->
          match instr with
          | Code.Let (x, _) when not (Code.Var.Set.mem x !var_set) ->
              var_set := Code.Var.Set.add x !var_set;
              var_decls := L.Assign ([evar x], [L.nil]) :: !var_decls
          | _ -> ())
        (get_body block);
      ()) p.blocks ()
  in

  let body = compile_closure p.blocks p.start in
  let params = (Code.Addr.Map.find p.start p.blocks).params in
  let fn_params = List.map params ~f:ident_of_var in
  (* Find first event in start block for a source comment *)
  let start_block = Code.Addr.Map.find p.start p.blocks in
  let src_comment = match get_body start_block with
    | Code.Event pi :: _ ->
        let file = match pi.src with Some f -> Filename.basename f | None -> "?" in
        [L.Comment (Printf.sprintf "# %s:%d" file pi.line)]
    | _ -> [L.Comment "# <unknown>"]
  in
  [ L.FunAssign (L.EVar (L.ident "_main"), fn_params,
                  src_comment @ List.rev !var_decls @ body)
  ]
