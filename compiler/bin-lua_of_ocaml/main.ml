(** lua_of_ocaml — compile OCaml bytecode to Lua 5.1 *)

open Js_of_ocaml_compiler.Stdlib
module Parse_bytecode = Js_of_ocaml_compiler.Parse_bytecode
module Runtime_lua = Lua_of_ocaml_compiler.Runtime_lua
module Generate_lua = Lua_of_ocaml_compiler.Generate_lua
module Lua_output = Lua_of_ocaml_compiler.Lua_output

let () =
  Sys.catch_break true;
  Js_of_ocaml_compiler.Config.set_target `JavaScript;
  ()

let write_output ~runtime oc lua_prog =
  Printf.eprintf "Generated %d statements\n" (List.length lua_prog);
  let fmt = Js_of_ocaml_compiler.Pretty_print.to_out_channel oc in
  if runtime then (
    Js_of_ocaml_compiler.Pretty_print.string fmt Runtime_lua.preamble;
    Js_of_ocaml_compiler.Pretty_print.newline fmt);
  Lua_output.program fmt lua_prog;
  if runtime then (
    Js_of_ocaml_compiler.Pretty_print.string fmt Runtime_lua.postamble)

let run input_file output_file =
  let ic = open_in_bin input_file in
  (match Parse_bytecode.from_channel ic with
   | `Exe ->
       let parsed = Parse_bytecode.from_exe ~linkall:false ~link_info:false
           ~include_cmis:false ic in
       close_in ic;
       let lua_prog = Generate_lua.compile_program parsed.code in
       let oc = match output_file with
         | Some f -> open_out_bin f
         | None -> stdout
       in
       write_output ~runtime:true oc lua_prog;
       if Option.is_some output_file then close_out oc
   | `Cmo (compunit) ->
       let parsed = Parse_bytecode.from_cmo compunit ic in
       close_in ic;
       let lua_prog = Generate_lua.compile_program parsed.Parse_bytecode.code in
       let oc = match output_file with
         | Some f -> open_out_bin f
         | None -> stdout
       in
       write_output ~runtime:true oc lua_prog;
       if Option.is_some output_file then close_out oc
   | `Cma lib ->
       let parsed = Parse_bytecode.from_cma lib ic in
       close_in ic;
       let lua_prog = Generate_lua.compile_program parsed.Parse_bytecode.code in
       let oc = match output_file with
         | Some f -> open_out_bin f
         | None -> stdout
       in
       write_output ~runtime:true oc lua_prog;
       if Option.is_some output_file then close_out oc)

let () =
  let input_file = ref None in
  let output_file = ref None in
  let args = List.tl (Array.to_list Sys.argv) in
  let rec parse_args = function
    | [] -> ()
    | "-o" :: f :: rest ->
        output_file := Some f;
        parse_args rest
    | f :: _rest when String.length f > 0 && Char.equal f.[0] '-' ->
        (* unknown flag, skip *)
        parse_args _rest
    | f :: rest ->
        input_file := Some f;
        parse_args rest
  in
  parse_args args;
  match !input_file with
  | None ->
      Printf.eprintf "Usage: lua_of_ocaml [options] <bytecode_file>\n";
      Printf.eprintf "  -o <file>  Output file (default: stdout)\n";
      exit 1
  | Some f ->
      run f !output_file
