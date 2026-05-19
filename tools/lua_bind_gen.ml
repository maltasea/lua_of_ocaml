(* lua_bind_gen — C header -> LuaJIT FFI + OCaml externals + C stubs
   Usage: ocaml -I +str str.cma tools/lua_bind_gen.ml [--prefix PREFIX] <header.h> *)

let prefix = ref ""
let remaining_args = ref []

let starts_with s prefix =
  String.length s >= String.length prefix
  && String.sub s 0 (String.length prefix) = prefix

let () =
  Arg.parse
    [ "--prefix", Arg.Set_string prefix,
      " Function name prefix to strip (e.g. RLAPI_)" ]
    (fun s -> remaining_args := s :: !remaining_args)
    "lua_bind_gen [--prefix PREFIX] <header.h>";

  let args = List.rev !remaining_args in
  if List.length args < 1 then
    (Printf.eprintf "Usage: lua_bind_gen [--prefix PREFIX] <header.h>\n"; exit 1);

  let header = List.hd args in
  let base = Filename.chop_extension (Filename.basename header) in

  (* Read header *)
  let ic = open_in header in
  let lines = ref [] in
  (try while true do lines := input_line ic :: !lines done with End_of_file -> ());
  close_in ic;
  let content = String.concat "\n" (List.rev !lines) in

  (* Pre-filter: remove comments, typedefs, struct/enum bodies *)
  let content =
    Str.global_replace (Str.regexp "//[^\n]*") "" content in
  let content =
    Str.global_replace (Str.regexp {|/\*[^*]*\*\+\([^/*][^*]*\*\+\)*/|}) "" content in
  let content_lines = String.split_on_char '\n' content in
  let content_lines = List.filter (fun line ->
      let t = String.trim line in
      t <> "" && not (starts_with t "typedef")
      && not (starts_with t "struct") && not (starts_with t "enum")
      && not (starts_with t "#") && not (starts_with t "}")
      && not (starts_with t "//")) content_lines
  in
  let content = String.concat "\n" content_lines in

  (* Parse function declarations *)
  let re = Str.regexp
    {|[A-Za-z_][A-Za-z0-9_* \t]+[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*\([^)]*\)[ \t]*;|} in

  let decls = ref [] in
  (* Find all lines matching: ...name(params); pattern *)
  let line_re = Str.regexp {|[A-Za-z_][A-Za-z0-9_]*[ \t]*([^)]*)[ \t]*;|} in
  let lines = String.split_on_char '\n' content in
  List.iter (fun line ->
    try
      let start = Str.search_forward line_re line 0 in
      let m = Str.matched_string line in
      if String.length m > 4 then (
        let paren_pos = String.index m '(' in
        let before = String.sub m 0 paren_pos in
        let before = String.trim before in
        let after = String.sub m (paren_pos+1) (String.length m - paren_pos - 3) in
        (* name is the last word before '(' *)
        let parts = Str.split (Str.regexp "[ \t]+") before in
        let parts = List.filter (fun s -> s <> "") parts in
        match List.rev parts with
        | name :: ret_parts ->
            let ret = String.concat " " (List.rev ret_parts) in
            let name =
              if !prefix <> "" && starts_with name !prefix
              then String.sub name (String.length !prefix)
                     (String.length name - String.length !prefix)
              else name in
            if String.length name >= 2
               && not (List.mem name ["type"; "char"; "int"; "float"; "void";
                                      "bool"; "short"; "long"; "unsigned"; "signed"; "const"])
            then decls := (ret, name, after) :: !decls
        | _ -> ())
    with Not_found -> ()) lines;

  let decls = List.rev !decls in
  Printf.eprintf "Parsed %d function declarations\n" (List.length decls);

  (* Map C type to OCaml type *)
  let ocaml_type = function
    | "void" -> "unit"
    | "int" | "unsigned" | "unsigned int" -> "int"
    | "float" | "double" -> "float"
    | "bool" | "_Bool" -> "bool"
    | "char" -> "int"
    | s when String.length s > 0 && s.[String.length s - 1] = '*' -> "string"
    | _ -> "int"
  in

  let clean_param s =
    let s = Str.global_replace (Str.regexp "[*]+$") "" s in
    let s = Str.global_replace (Str.regexp "\\[.*\\]") "" s in
    s
  in

  let snake_name s =
    let b = Buffer.create (String.length s) in
    String.iter (fun c ->
        if c >= 'A' && c <= 'Z'
        then (Buffer.add_char b '_'; Buffer.add_char b (Char.lowercase_ascii c))
        else Buffer.add_char b c) s;
    let s = Buffer.contents b in
    if String.length s > 0 && s.[0] = '_'
    then String.sub s 1 (String.length s - 1) else s
  in

  let ocaml_params = Hashtbl.create 64 in
  let ocaml_results = Hashtbl.create 64 in

  (* --- OCaml externals --- *)
  let ocaml_file = base ^ "_external.ml" in
  let oc = open_out ocaml_file in
  Printf.fprintf oc "(* Auto-generated from %s *)\n\n" (Filename.basename header);
  let written = ref 0 in
  List.iter (fun (ret, name, params_str) ->
    try
      let params =
        if params_str = "void" || params_str = "" then []
        else List.filter (fun s -> s <> "")
               (Str.split (Str.regexp ",") params_str)
      in
      let params = List.map (fun p ->
          let p = String.trim p in
          let parts = List.rev (Str.split (Str.regexp "[ \t]+") p) in
          match parts with
          | pname :: type_parts ->
              (ocaml_type (String.concat " " (List.rev type_parts)), clean_param pname)
          | _ -> ("int", "x")) params
      in
      let lua_name = snake_name name in
      let sig_ = String.concat " -> " (List.map fst params @ [ocaml_type ret]) in
      Printf.fprintf oc "external %s : %s = \"%s\"\n" lua_name sig_ lua_name;
      Hashtbl.add ocaml_params lua_name params;
      Hashtbl.add ocaml_results lua_name (ocaml_type ret);
      incr written
    with _ -> Printf.eprintf "SKIP %s\n" name);
  close_out oc;
  Printf.printf "Wrote %s (%d externals)\n" ocaml_file !written;

  (* --- C stubs --- *)
  let c_file = base ^ "_stubs.c" in
  let c = open_out c_file in
  Printf.fprintf c "/* Auto-generated from %s */\n" (Filename.basename header);
  Printf.fprintf c "#include <caml/mlvalues.h>\n";
  List.iter (fun (_ret, name, _params_str) ->
      let lua_name = snake_name name in
      let params = try Hashtbl.find ocaml_params lua_name with Not_found -> [] in
      Printf.fprintf c "CAMLprim value %s(" lua_name;
      let n = List.length params in
      for i = 1 to n do
        Printf.fprintf c "value v%d%s" i (if i < n then "," else "");
      done;
      Printf.fprintf c ") {";
      for i = 1 to n do Printf.fprintf c "(void)v%d;" i done;
      let ret = try Hashtbl.find ocaml_results lua_name with Not_found -> "unit" in
      (match ret with
       | "unit" -> Printf.fprintf c " return Val_unit;"
       | "int"  -> Printf.fprintf c " return Val_int(0);"
       | "bool" -> Printf.fprintf c " return Val_bool(0);"
       | _      -> Printf.fprintf c " return Val_int(0);");
      Printf.fprintf c " }\n");
  close_out c;
  Printf.printf "Wrote %s\n" c_file;

  (* --- LuaJIT bindings --- *)
  let lua_file = base ^ "_bindings.lua" in
  let l = open_out lua_file in
  Printf.fprintf l "-- Auto-generated from %s\n" (Filename.basename header);
  Printf.fprintf l "local ffi = require(\"ffi\")\n\n";
  Printf.fprintf l "ffi.cdef([[\n";
  List.iter (fun (ret, name, params_str) ->
      Printf.fprintf l "  %s %s(%s);\n" ret name params_str) decls;
  Printf.fprintf l "]])\n\nlocal C = ffi.C\n\n";

  Printf.fprintf l "local function ocaml_int(v)\n  if type(v) == \"number\" then return math.floor(v / 2) end\n  return v or 0\nend\n\n";
  Printf.fprintf l "local function ocaml_float(v)\n  if type(v) == \"table\" and v[1] == 253 then return v[2] or 0 end\n  if type(v) == \"number\" then return v / 2 end\n  return v or 0\nend\n\n";
  Printf.fprintf l "local function ocaml_string(v) return v end\n\n";

  Printf.fprintf l "-- Wrappers (OCaml external -> C call with value conversion)\n";
  List.iter (fun (_ret, name, _params_str) ->
      let lua_name = snake_name name in
      let params = try Hashtbl.find ocaml_params lua_name with Not_found -> [] in
      let n = List.length params in
      if n = 0 then
        Printf.fprintf l "function %s() return C.%s() end\n" lua_name name
      else (
        Printf.fprintf l "function %s(" lua_name;
        for i = 1 to n do Printf.fprintf l "a%d%s" i (if i < n then "," else ""); done;
        Printf.fprintf l ")\n  return C.%s(" name;
        for i = 1 to n do
          let ctype, _ = List.nth params (i-1) in
          (match ctype with
           | "int" | "bool" -> Printf.fprintf l "ocaml_int(a%d)" i
           | "float" | "double" -> Printf.fprintf l "ocaml_float(a%d)" i
           | "string" -> Printf.fprintf l "ocaml_string(a%d)" i
           | _ -> Printf.fprintf l "a%d" i);
          if i < n then Printf.fprintf l ", ";
        done;
        Printf.fprintf l ")\nend\n");
      Printf.fprintf l "\n") decls;

  close_out l;
  Printf.printf "Wrote %s\n" lua_file
