external ffi_external_add : int -> int -> int = "ffi_external_add"
external ffi_external_join : string -> string -> string = "ffi_external_join"
external ffi_external_note : string -> unit = "ffi_external_note"
external ffi_external_last_note : unit -> string = "ffi_external_last_note"
external ffi_external_call_cb : (int -> int) -> int -> int
  = "ffi_external_call_cb"

let check_int label expected actual =
  if actual <> expected then failwith label

let check_string label expected actual =
  if actual <> expected then failwith label

let callback x = (x * 2) + 1

let () =
  check_int "ffi_external_add" 42 (ffi_external_add 19 23);
  check_string "ffi_external_join" "left:right" (ffi_external_join "left" "right");
  ffi_external_note "from ocaml";
  check_string "ffi_external_note" "from ocaml" (ffi_external_last_note ());
  check_int "ffi_external_call_cb" 43 (ffi_external_call_cb callback 21);
  print_endline "ffi roundtrip ok"
