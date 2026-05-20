(** lua_of_ocaml — compile OCaml bytecode to Lua 5.1 *)

open Js_of_ocaml_compiler.Stdlib
module Parse_bytecode = Js_of_ocaml_compiler.Parse_bytecode
module Generate_lua = Lua_of_ocaml_compiler.Generate_lua
module Output_lua = Lua_of_ocaml_compiler.Output_lua

let () =
  Sys.catch_break true;
  Js_of_ocaml_compiler.Config.set_target `JavaScript

(* Runtime files. Search order:
     1.  --runtime DIR  CLI flag
     2.  $LOO_RUNTIME    env var
     3.  ./runtime/lua   relative to cwd (dev tree)
     4.  <bindir>/../share/lua_of_ocaml/runtime/lua  (installed layout)
   First location that exists wins. *)

let runtime_files =
  [ "stdlib.lua"; "ints.lua"; "obj.lua"; "fail.lua"
  ; "string.lua"; "array.lua"; "io.lua"; "misc.lua"
  ]

let dir_has_runtime dir =
  Sys.file_exists dir
  && List.for_all runtime_files ~f:(fun f ->
         Sys.file_exists (Filename.concat dir f))

let runtime_dir_default =
  let cwd_default = "runtime/lua" in
  let installed_default =
    let bin = Sys.argv.(0) in
    let bindir = Filename.dirname bin in
    Filename.concat bindir "../share/lua_of_ocaml/runtime/lua"
  in
  let env =
    try Some (Sys.getenv "LOO_RUNTIME") with Not_found -> None
  in
  match env with
  | Some d when dir_has_runtime d -> d
  | Some d ->
      Printf.eprintf "ERROR: LOO_RUNTIME=%s is missing runtime files\n" d;
      exit 1
  | None when dir_has_runtime cwd_default -> cwd_default
  | None when dir_has_runtime installed_default -> installed_default
  | None ->
      Printf.eprintf
        "ERROR: cannot locate runtime/lua. Tried:\n  %s\n  %s\nSet LOO_RUNTIME or pass --runtime DIR.\n"
        cwd_default installed_default;
      exit 1

let load_runtime dir =
  let buf = Buffer.create 4096 in
  List.iter runtime_files ~f:(fun f ->
      let path = Filename.concat dir f in
      let ic = open_in_bin path in
      let content = really_input_string ic (in_channel_length ic) in
      close_in ic;
      Buffer.add_string buf content;
      Buffer.add_char buf '\n');
  Buffer.contents buf

let write_output ~runtime_dir ~source_file oc lua_prog =
  let fmt = Js_of_ocaml_compiler.Pretty_print.to_out_channel oc in
  Js_of_ocaml_compiler.Pretty_print.string fmt
    (Printf.sprintf "--# source: %s\n" source_file);
  Js_of_ocaml_compiler.Pretty_print.string fmt (load_runtime runtime_dir);
  Output_lua.program fmt lua_prog;
  Js_of_ocaml_compiler.Pretty_print.string fmt "_main()\n"

let run ~runtime_dir input_file output_file =
  let ic = open_in_bin input_file in
  let compile_and_emit code =
    let lua_prog = Generate_lua.compile_program code in
    let oc = match output_file with
      | Some f -> open_out_bin f
      | None -> stdout
    in
    write_output ~runtime_dir ~source_file:input_file oc lua_prog;
    if Option.is_some output_file then close_out oc
  in
  (match Parse_bytecode.from_channel ic with
   | `Exe ->
       let parsed = Parse_bytecode.from_exe ~linkall:false ~link_info:false
           ~include_cmis:false ~debug:true ic in
       close_in ic;
       compile_and_emit parsed.code
   | `Cmo compunit ->
       let parsed = Parse_bytecode.from_cmo ~debug:true compunit ic in
       close_in ic;
       compile_and_emit parsed.Parse_bytecode.code
   | `Cma lib ->
       let parsed = Parse_bytecode.from_cma ~debug:true lib ic in
       close_in ic;
       compile_and_emit parsed.Parse_bytecode.code)

let () =
  let input_file = ref None in
  let output_file = ref None in
  let runtime_override = ref None in
  let args = List.tl (Array.to_list Sys.argv) in
  let rec parse_args = function
    | [] -> ()
    | "-o" :: f :: rest -> output_file := Some f; parse_args rest
    | ("--runtime" | "-runtime") :: d :: rest ->
        runtime_override := Some d; parse_args rest
    | "--help" :: _ | "-h" :: _ ->
        print_endline "Usage: lua_of_ocaml [options] <bytecode_file>";
        print_endline "  -o <file>       Output file (default: stdout)";
        print_endline "  --runtime <dir> Path to runtime/lua directory";
        print_endline "  Env LOO_RUNTIME overrides the search path.";
        exit 0
    | f :: rest when String.length f > 0 && Char.equal f.[0] '-' ->
        parse_args rest  (* unknown flag, skip *)
    | f :: rest ->
        input_file := Some f; parse_args rest
  in
  parse_args args;
  let runtime_dir = match !runtime_override with
    | Some d when dir_has_runtime d -> d
    | Some d ->
        Printf.eprintf "ERROR: --runtime %s is missing runtime files\n" d; exit 1
    | None -> runtime_dir_default
  in
  match !input_file with
  | None ->
      Printf.eprintf "Usage: lua_of_ocaml [options] <bytecode_file>\n";
      Printf.eprintf "  -o <file>       Output file (default: stdout)\n";
      Printf.eprintf "  --runtime <dir> Path to runtime/lua directory\n";
      exit 1
  | Some f ->
      run ~runtime_dir f !output_file
