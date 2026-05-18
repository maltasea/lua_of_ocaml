(** Translate Code.program (jsoo IR) into Lua.program. *)

open Js_of_ocaml_compiler.Stdlib
module L = Lua
module Code = Js_of_ocaml_compiler.Code
module Targetint = Js_of_ocaml_compiler.Targetint

(* Global ref for blocks map, set by compile_program *)
let current_blocks : Code.block Code.Addr.Map.t ref = ref Code.Addr.Map.empty

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

(* ---- Constant translation ---- *)

let rec translate_constant = function
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
  | Code.Float _ -> make_block (L.int_ 253) [L.int_ 0]
  | Code.Tuple (tag, fields, _) ->
      let fields = Array.to_list (Array.map fields ~f:translate_constant) in
      make_block (L.int_ tag) fields
  | Code.Float_array _ -> make_block (L.int_ 253) [L.int_ 0]
  | Code.Int64 _ -> L.int_ 0

(* ---- Expression translation ---- *)

and translate_expr = function
  | Code.Apply { f; args; _ } ->
      L.call (evar f) (List.map args ~f:evar)
  | Code.Block (tag, fields, _, _) ->
      make_block (L.int_ tag) (Array.to_list (Array.map fields ~f:evar))
  | Code.Field (x, n, _) -> block_field (evar x) n
  | Code.Closure (params, (pc, _), _) ->
      let params' = List.map params ~f:ident_of_var in
      L.EFun (params', closure_body pc, false)
  | Code.Constant c -> translate_constant c
  | Code.Prim (p, args) -> translate_prim p args
  | Code.Special (Code.Alias_prim name) ->
      L.EVar (L.ident (clean_extern name))

and clean_extern name =
  if String.length name > 0 && Char.equal name.[0] '%'
  then String.sub name ~pos:1 ~len:(String.length name - 1)
  else name

and translate_prim p args =
  let pa a = match a with Code.Pv v -> evar v | Code.Pc c -> translate_constant c in
  match p, args with
  | Code.Vectlength, [a] -> L.bin L.Sub (L.EUn (L.Len, pa a)) one
  | Code.Array_get, [a; b] -> L.access (pa a) (L.bin L.Add (pa b) one)
  | Code.Not, [a] -> L.EUn (L.Not, pa a)
  | Code.IsInt, [a] ->
      L.bin L.Eq (L.call (L.EVar (L.ident "type")) [pa a]) (L.string_ "number")
  | Code.Eq, [a; b] -> L.bin L.Eq (pa a) (pa b)
  | Code.Neq, [a; b] -> L.bin L.Neq (pa a) (pa b)
  | Code.Lt, [a; b] -> L.bin L.Lt (pa a) (pa b)
  | Code.Le, [a; b] -> L.bin L.Le (pa a) (pa b)
  | Code.Ult, [a; b] -> L.bin L.Lt (pa a) (pa b)
  | Code.Extern name, args ->
      L.call (L.EVar (L.ident (clean_extern name))) (List.map args ~f:pa)
  | _ ->
      L.call (L.EVar (L.ident "caml_prim_missing")) (List.map args ~f:pa)

(* ---- Closure body: compile inner CFG as a while-switch trampoline ---- *)

and bind_args tgt_params arg_vars =
  if List.length tgt_params = List.length arg_vars
  then List.map2 tgt_params arg_vars ~f:(fun p a -> L.Assign ([evar p], [evar a]))
  else []

and closure_body entry_pc =
  let visited = ref Code.Addr.Set.empty in
  let blocks = ref [] in
  let rec collect pc =
    if not (Code.Addr.Set.mem pc !visited) then (
      visited := Code.Addr.Set.add pc !visited;
      let b = Code.Addr.Map.find pc !current_blocks in
      blocks := (pc, b) :: !blocks;
      List.iter b.body ~f:(fun instr ->
          match instr with
          | Code.Let (_, Code.Closure (_, (pc', _), _)) ->
              if Code.Addr.Map.mem pc' !current_blocks then collect pc'
          | _ -> ());
      match b.branch with
      | Code.Branch (pc', _) -> collect pc'
      | Code.Cond (_, (pc1, _), (pc2, _)) -> collect pc1; collect pc2
      | Code.Switch (_, cases) -> Array.iter cases ~f:(fun (pc', _) -> collect pc')
      | Code.Pushtrap ((pc_h, _), _, (pc_c, _)) -> collect pc_h; collect pc_c
      | Code.Poptrap _ | Code.Return _ | Code.Raise _ | Code.Stop -> ())
  in
  collect entry_pc;

  (* Helper to extract record fields *)
  let get_params (b : Js_of_ocaml_compiler.Code.block) = b.params in
  let get_body (b : Js_of_ocaml_compiler.Code.block) = b.body in
  let get_branch (b : Js_of_ocaml_compiler.Code.block) = b.branch in

  (* Forward-declare all variables *)
  let var_set = ref Code.Var.Set.empty in
  let var_decls = ref [] in
  let declare v =
    if not (Code.Var.Set.mem v !var_set) then (
      var_set := Code.Var.Set.add v !var_set;
      var_decls := L.Assign ([evar v], [L.nil]) :: !var_decls)
  in
  List.iter !blocks ~f:(fun (_pc, b) ->
      let params = get_params b in
      let body = get_body b in
      let branch = get_branch b in
      List.iter params ~f:declare;
      List.iter body ~f:(fun instr ->
          match instr with
          | Code.Let (x, _) -> declare x
          | _ -> ());
      (match branch with
       | Code.Pushtrap (_, x, _) -> declare x
       | _ -> ()));

  (* Runtime variables *)
  let pc_var = L.ident "_pc" in
  let exn_var = L.ident "_exn" in
  let exn_sp_var = L.ident "_exn_sp" in

  (* Build per-block switch cases *)
  let switch_cases = List.rev_map !blocks ~f:(fun (pc, b) ->
      let body = get_body b in
      let branch = get_branch b in
      let pc_val = L.int_ (pc :> int) in
      let instr_stmts = List.concat_map body ~f:(function
          | Code.Let (x, e) -> [L.Assign ([evar x], [translate_expr e])]
          | Code.Assign (x, y) -> [L.Assign ([evar x], [evar y])]
          | Code.Set_field (x, n, _, y) ->
              [L.Assign ([block_field (evar x) n], [evar y])]
          | Code.Offset_ref (x, n) ->
              let f = block_field (evar x) 0 in
              let rhs = match n with
                | 0 -> f
                | 1 -> L.bin L.Add f one
                | -1 -> L.bin L.Sub f one
                | n when n < 0 -> L.bin L.Sub f (L.int_ (-n))
                | _ -> L.bin L.Add f (L.int_ n)
              in
              [L.Assign ([block_field (evar x) 0], [rhs])]
          | Code.Array_set (x, y, z) ->
              [L.Assign ([L.access (evar x) (L.bin L.Add (evar y) one)], [evar z])]
          | Code.Event _ -> [])
      in
      let term_stmts = match branch with
        | Code.Return x -> [L.Return [evar x]]
        | Code.Stop -> [L.Return []]

        | Code.Raise (x, _) ->
            (* Unwind exception stack, jump to handler *)
            let f = L.ident "_f" in
            [ L.If (L.bin L.Gt (L.EVar exn_sp_var) (L.int_ 0),
                (* Pop frame: read at _exn_sp, then decrement *)
                [ L.Assign ([L.EVar f], [L.access (L.EVar exn_var) (L.EVar exn_sp_var)])
                ; L.Assign ([L.EVar exn_sp_var], [L.bin L.Sub (L.EVar exn_sp_var) one])
                ; L.ExprStmt (L.call (L.EVar (L.ident "caml_set_global"))
                               [L.access (L.EVar f) one; evar x])
                ; L.ExprStmt (L.call (L.EVar (L.ident "caml_bind_frame"))
                               [L.EVar f])
                ; L.Assign ([L.EVar pc_var], [L.access (L.EVar f) two])
                ],
                [],
                (* No handler *)
                Some [ L.ExprStmt (L.call (L.EVar (L.ident "caml_raise")) [evar x])
                     ; L.Assign ([L.EVar pc_var], [L.int_ (-1)])
                     ])
            ]

        | Code.Branch (pc', args) ->
            let tgt = get_params (Code.Addr.Map.find pc' !current_blocks) in
            bind_args tgt args
            @ [L.Assign ([L.EVar pc_var], [L.int_ (pc' :> int)])]

        | Code.Cond (x, (pc1, args1), (pc2, args2)) ->
            let tgt1 = get_params (Code.Addr.Map.find pc1 !current_blocks) in
            let tgt2 = get_params (Code.Addr.Map.find pc2 !current_blocks) in
            let body1 = bind_args tgt1 args1
                        @ [L.Assign ([L.EVar pc_var], [L.int_ (pc1 :> int)])] in
            let body2 = bind_args tgt2 args2
                        @ [L.Assign ([L.EVar pc_var], [L.int_ (pc2 :> int)])] in
            [L.If (evar x, body1, [], Some body2)]

        | Code.Switch (x, cases) ->
            let n = Array.length cases in
            let rec build_cases i =
              if i >= n then []
              else
                let (pc', args') = cases.(i) in
                let tgt = get_params (Code.Addr.Map.find pc' !current_blocks) in
                let body = bind_args tgt args'
                           @ [L.Assign ([L.EVar pc_var], [L.int_ (pc' :> int)])] in
                L.If (L.bin L.Eq (evar x) (L.int_ i), body, [], None)
                :: build_cases (i + 1)
            in
            build_cases 0

        | Code.Pushtrap ((pc_h, args_h), x, (pc_c, args_c)) ->
            (* Push handler frame: {x_name, handler_pc, param_names, arg_values}
               x_name is the Lua variable name to store the caught exception into *)
            let h_params = get_params (Code.Addr.Map.find pc_h !current_blocks) in
            let frame = L.table
                [ L.TArray (L.string_ (var_str x))
                ; L.TArray (L.int_ (pc_h :> int))
                ; L.TArray (L.table (List.map h_params
                                        ~f:(fun p -> L.TArray (L.string_ (var_str p)))))
                ; L.TArray (L.table (List.map args_h ~f:(fun v -> L.TArray (evar v))))
                ]
            in
            let push_exn = L.Assign ([L.EVar exn_sp_var],
                                      [L.bin L.Add (L.EVar exn_sp_var) one]) in
            let store_frame = L.Assign
                ([L.access (L.EVar exn_var) (L.EVar exn_sp_var)], [frame]) in
            let tgt_c = get_params (Code.Addr.Map.find pc_c !current_blocks) in
            L.Assign ([evar x], [make_block (L.int_ 0) []])
            :: push_exn
            :: store_frame
            :: bind_args tgt_c args_c
            @ [L.Assign ([L.EVar pc_var], [L.int_ (pc_c :> int)])]

        | Code.Poptrap (pc_after, args) ->
            (* Pop exception stack *)
            let pop_exn = L.Assign ([L.EVar exn_sp_var],
                                     [L.bin L.Sub (L.EVar exn_sp_var) one]) in
            let tgt = get_params (Code.Addr.Map.find pc_after !current_blocks) in
            pop_exn
            :: bind_args tgt args
            @ [L.Assign ([L.EVar pc_var], [L.int_ (pc_after :> int)])]
      in
      (pc_val, instr_stmts @ term_stmts))
  in

  let while_body =
    List.concat_map switch_cases ~f:(fun (pc_val, stmts) ->
        [L.If (L.bin L.Eq (L.EVar pc_var) pc_val, stmts, [], None)])
  in

  let f_tmp = L.ident "_f" in
  let exn_init =
    [ L.Assign ([L.EVar exn_var], [L.table []])
    ; L.Assign ([L.EVar exn_sp_var], [L.int_ 0])
    ; L.Assign ([L.EVar f_tmp], [L.nil])
    ]
  in
  let pc_init = L.Assign ([L.EVar pc_var], [L.int_ (entry_pc :> int)]) in
  let exit_check = L.If (L.bin L.Eq (L.EVar pc_var) (L.int_ (-1)),
                          [L.Return [L.int_ 0]], [], None) in
  let while_loop = L.While (L.bool_ true,
    exit_check
    :: (List.rev !var_decls)
    @ exn_init
    @ [pc_init]
    @ while_body)
  in
  [while_loop]

(* ---- Program compilation ---- *)

let compile_program (p : Code.program) =
  current_blocks := p.blocks;
  [ closure_body p.start ]
  |> List.concat
