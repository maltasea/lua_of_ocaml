(* JSON parser + printer.  Exercises:
   - recursive variant types
   - char-by-char string parsing with Bytes mutation
   - float parsing and printing
   - exceptions (carrying values and nested try/with)
   - List/Buffer manipulation
   - Printf
   - higher-order combinators (List.map / fold) *)

type json =
  | JNull
  | JBool of bool
  | JNum of float
  | JStr of string
  | JArr of json list
  | JObj of (string * json) list

exception Parse_error of int * string

(* ---- parser ---- *)
type st = { src : string; mutable pos : int }

let make s = { src = s; pos = 0 }
let peek st = if st.pos >= String.length st.src then '\000' else st.src.[st.pos]
let bump st = st.pos <- st.pos + 1
let err st msg = raise (Parse_error (st.pos, msg))

let rec skip_ws st =
  match peek st with
  | ' ' | '\t' | '\n' | '\r' -> bump st; skip_ws st
  | _ -> ()

let expect st c =
  if peek st = c then bump st
  else err st (Printf.sprintf "expected %c" c)

let parse_string st =
  expect st '"';
  let b = Buffer.create 16 in
  let rec loop () =
    match peek st with
    | '"' -> bump st
    | '\\' ->
        bump st;
        (match peek st with
         | 'n' -> Buffer.add_char b '\n'
         | 't' -> Buffer.add_char b '\t'
         | '"' -> Buffer.add_char b '"'
         | '\\' -> Buffer.add_char b '\\'
         | c -> Buffer.add_char b c);
        bump st;
        loop ()
    | '\000' -> err st "unterminated string"
    | c -> Buffer.add_char b c; bump st; loop ()
  in
  loop ();
  Buffer.contents b

let parse_num st =
  let start = st.pos in
  if peek st = '-' then bump st;
  while (let c = peek st in c >= '0' && c <= '9') do bump st done;
  if peek st = '.' then begin
    bump st;
    while (let c = peek st in c >= '0' && c <= '9') do bump st done
  end;
  let s = String.sub st.src start (st.pos - start) in
  try float_of_string s
  with _ -> err st ("bad number: " ^ s)

let rec parse_value st =
  skip_ws st;
  match peek st with
  | 'n' ->
      if String.sub st.src st.pos 4 = "null"
      then (st.pos <- st.pos + 4; JNull)
      else err st "expected null"
  | 't' ->
      if String.sub st.src st.pos 4 = "true"
      then (st.pos <- st.pos + 4; JBool true)
      else err st "expected true"
  | 'f' ->
      if String.sub st.src st.pos 5 = "false"
      then (st.pos <- st.pos + 5; JBool false)
      else err st "expected false"
  | '"' -> JStr (parse_string st)
  | '[' -> bump st; parse_array st
  | '{' -> bump st; parse_object st
  | c when c = '-' || (c >= '0' && c <= '9') -> JNum (parse_num st)
  | c -> err st (Printf.sprintf "unexpected %c" c)

and parse_array st =
  skip_ws st;
  if peek st = ']' then (bump st; JArr [])
  else
    let rec loop acc =
      let v = parse_value st in
      skip_ws st;
      match peek st with
      | ',' -> bump st; loop (v :: acc)
      | ']' -> bump st; JArr (List.rev (v :: acc))
      | _ -> err st "expected , or ]"
    in
    loop []

and parse_object st =
  skip_ws st;
  if peek st = '}' then (bump st; JObj [])
  else
    let rec loop acc =
      skip_ws st;
      let k = parse_string st in
      skip_ws st;
      expect st ':';
      let v = parse_value st in
      skip_ws st;
      match peek st with
      | ',' -> bump st; loop ((k, v) :: acc)
      | '}' -> bump st; JObj (List.rev ((k, v) :: acc))
      | _ -> err st "expected , or }"
    in
    loop []

let parse s =
  let st = make s in
  let v = parse_value st in
  skip_ws st;
  if st.pos < String.length st.src then err st "trailing input";
  v

(* ---- printer ---- *)
let rec print buf = function
  | JNull -> Buffer.add_string buf "null"
  | JBool true -> Buffer.add_string buf "true"
  | JBool false -> Buffer.add_string buf "false"
  | JNum n ->
      let s =
        if Float.is_integer n && Float.abs n < 1e15
        then Printf.sprintf "%.0f" n
        else Printf.sprintf "%g" n
      in
      Buffer.add_string buf s
  | JStr s ->
      Buffer.add_char buf '"';
      String.iter (fun c ->
        match c with
        | '"' -> Buffer.add_string buf "\\\""
        | '\\' -> Buffer.add_string buf "\\\\"
        | '\n' -> Buffer.add_string buf "\\n"
        | c -> Buffer.add_char buf c) s;
      Buffer.add_char buf '"'
  | JArr [] -> Buffer.add_string buf "[]"
  | JArr xs ->
      Buffer.add_char buf '[';
      let first = ref true in
      List.iter (fun x ->
        if !first then first := false else Buffer.add_char buf ',';
        print buf x) xs;
      Buffer.add_char buf ']'
  | JObj [] -> Buffer.add_string buf "{}"
  | JObj kvs ->
      Buffer.add_char buf '{';
      let first = ref true in
      List.iter (fun (k, v) ->
        if !first then first := false else Buffer.add_char buf ',';
        print buf (JStr k);
        Buffer.add_char buf ':';
        print buf v) kvs;
      Buffer.add_char buf '}'

let to_string v =
  let b = Buffer.create 64 in
  print b v;
  Buffer.contents b

(* ---- driver ---- *)
let cases = [
  {|null|};
  {|true|};
  {|42|};
  {|-3.14|};
  {|"hello\nworld"|};
  {|[1,2,3]|};
  {|{"name":"loo","age":1,"alive":true}|};
  {|{"nested":{"arr":[1,"two",null,false],"empty":[]},"x":42}|};
]

let () =
  List.iter (fun input ->
    try
      let v = parse input in
      let out = to_string v in
      Printf.printf "%-50s -> %s\n" input out
    with Parse_error (pos, msg) ->
      Printf.printf "%-50s -> ERR@%d %s\n" input pos msg
  ) cases;
  (* Error case *)
  (try ignore (parse "[1,2,") with
   | Parse_error (pos, msg) ->
       Printf.printf "unterminated -> ERR@%d %s\n" pos msg)
