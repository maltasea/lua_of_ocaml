(* XFAIL: multiple format placeholders.  Our codegen uses globals for
   IR variables to dodge Lua 5.1's 200-locals limit, but closures then
   read those globals at call time instead of capturing the value at
   creation time.  Printf chains several closures over a recursive
   make_printf, and stale captures cause the leading literal to repeat. *)
let () =
  Printf.printf "abc%dxyz\n" 42;
  Printf.printf "%d %s\n" 42 "hi"
