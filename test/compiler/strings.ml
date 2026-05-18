let () =
  let s = "hello" ^ " " ^ "world" in
  let len = String.length s in
  let ch = s.[0] in
  ignore (len, ch)
