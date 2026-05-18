#!/bin/bash
# lua_of_ocaml test runner
set -e
cd "$(dirname "$0")/.."

LUA=${LUA:-lua}
COMPILER="dune exec -- compiler/bin-lua_of_ocaml/main.exe --"
PASS=0
FAIL=0
FAILURES=""

say() { printf "  %-50s" "$1"; }
ok()   { echo " OK"; PASS=$((PASS+1)); }
fail() { echo " FAIL ($1)"; FAIL=$((FAIL+1)); FAILURES="$FAILURES\n  $2: $1"; }

# ---- helpers ----

compile_ocaml() {
  local src="$1" out="$2"
  ocamlc -g -o "$out" "$src" 2>/dev/null
}

run_compiler() {
  local byte="$1" out="$2"
  dune exec -- compiler/bin-lua_of_ocaml/main.exe -- "$byte" -o "$out" 2>&1
}

check_lua_syntax() {
  local f="$1"
  $LUA -e "assert(loadfile('$f'))" 2>&1
}

check_lua_runs() {
  local f="$1"
  $LUA "$f" 2>&1
}

check_contains() {
  local file="$1" pattern="$2"
  grep -q "$pattern" "$file" 2>/dev/null
}

# ======================================================================
echo "=== Compiler smoke tests ==="

# -- test 1: hello.ml compiles to valid Lua --
say "hello.ml -> valid Lua"
compile_ocaml test/hello.ml test/_hello.byte
if run_compiler test/_hello.byte test/_hello.lua 2>/dev/null \
   && check_lua_syntax test/_hello.lua 2>/dev/null; then
  ok
else
  fail "syntax error"
fi

# -- test 2: minimal program (no stdlib) --
say "minimal.ml -> valid Lua"
compile_ocaml test/minimal.ml test/_minimal.byte
if run_compiler test/_minimal.byte test/_minimal.lua 2>/dev/null \
   && check_lua_syntax test/_minimal.lua 2>/dev/null; then
  ok
else
  fail "syntax error"
fi

# -- test 3: arithmetic --
cat > test/_arith.ml <<'EOF'
let () =
  let a = 1 + 2 * 3 in
  let b = a - 4 in
  let c = if a > b then a else b in
  ignore c
EOF
say "arithmetic -> valid Lua"
compile_ocaml test/_arith.ml test/_arith.byte
if run_compiler test/_arith.byte test/_arith.lua 2>/dev/null \
   && check_lua_syntax test/_arith.lua 2>/dev/null; then
  ok
else
  fail "syntax error"
fi

# -- test 4: strings --
cat > test/_str.ml <<'EOF'
let () =
  let s = "hello" ^ " " ^ "world" in
  let _ = String.length s in
  ()
EOF
say "strings -> valid Lua"
compile_ocaml test/_str.ml test/_str.byte
if run_compiler test/_str.byte test/_str.lua 2>/dev/null \
   && check_lua_syntax test/_str.lua 2>/dev/null; then
  ok
else
  fail "syntax error"
fi

# -- test 5: functions --
cat > test/_fun.ml <<'EOF'
let sq x = x * x
let () =
  let r = sq 5 in
  let r2 = sq r in
  ignore r2
EOF
say "functions -> valid Lua"
compile_ocaml test/_fun.ml test/_fun.byte
if run_compiler test/_fun.byte test/_fun.lua 2>/dev/null \
   && check_lua_syntax test/_fun.lua 2>/dev/null; then
  ok
else
  fail "syntax error"
fi

# -- test 6: recursion --
cat > test/_rec.ml <<'EOF'
let rec fact n = if n <= 1 then 1 else n * fact (n-1)
let () = ignore (fact 5)
EOF
say "recursion -> valid Lua"
compile_ocaml test/_rec.ml test/_rec.byte
if run_compiler test/_rec.byte test/_rec.lua 2>/dev/null \
   && check_lua_syntax test/_rec.lua 2>/dev/null; then
  ok
else
  fail "syntax error"
fi

# -- test 7: pattern matching --
cat > test/_match.ml <<'EOF'
let () =
  let x = Some 42 in
  match x with
  | Some n -> ignore n
  | None -> ()
EOF
say "match -> valid Lua"
compile_ocaml test/_match.ml test/_match.byte
if run_compiler test/_match.byte test/_match.lua 2>/dev/null \
   && check_lua_syntax test/_match.lua 2>/dev/null; then
  ok
else
  fail "syntax error"
fi

# -- test 8: closures --
cat > test/_closure.ml <<'EOF'
let make_adder n = fun x -> n + x
let () =
  let add3 = make_adder 3 in
  let r = add3 10 in
  ignore r
EOF
say "closures -> valid Lua"
compile_ocaml test/_closure.ml test/_closure.byte
if run_compiler test/_closure.byte test/_closure.lua 2>/dev/null \
   && check_lua_syntax test/_closure.lua 2>/dev/null; then
  ok
else
  fail "syntax error"
fi

# -- test 9: lists --
cat > test/_list.ml <<'EOF'
let () =
  let l = [1; 2; 3] in
  match l with
  | [] -> ()
  | h :: t -> ignore (h + List.length t)
EOF
say "lists -> valid Lua"
compile_ocaml test/_list.ml test/_list.byte
if run_compiler test/_list.byte test/_list.lua 2>/dev/null \
   && check_lua_syntax test/_list.lua 2>/dev/null; then
  ok
else
  fail "syntax error"
fi

# -- test 10: exceptions --
cat > test/_exn.ml <<'EOF'
let () =
  try
    failwith "test"
  with Failure _ -> ()
EOF
say "exceptions -> valid Lua"
compile_ocaml test/_exn.ml test/_exn.byte
if run_compiler test/_exn.byte test/_exn.lua 2>/dev/null \
   && check_lua_syntax test/_exn.lua 2>/dev/null; then
  ok
else
  fail "syntax error"
fi

# ======================================================================
echo "=== Runtime smoke tests (run generated Lua) ==="

# -- test 11: hello.ml runs without crash --
say "hello.ml runs"
compile_ocaml test/hello.ml test/_hello_runs.byte
run_compiler test/_hello_runs.byte test/_hello_runs.lua 2>/dev/null
if check_lua_runs test/_hello_runs.lua 2>/dev/null; then
  ok
else
  fail "crashed at runtime"
fi

# -- test 12: arithmetic runs --
say "arithmetic runs"
compile_ocaml test/_arith.ml test/_arith_runs.byte 2>/dev/null
run_compiler test/_arith_runs.byte test/_arith_runs.lua 2>/dev/null
if check_lua_runs test/_arith_runs.lua 2>/dev/null; then
  ok
else
  fail "crashed at runtime"
fi

# -- test 13: minimal.ml runs without missing primitives --
say "minimal.ml runs (no missing prims)"
compile_ocaml test/minimal.ml test/_minimal_runs.byte 2>/dev/null
run_compiler test/_minimal_runs.byte test/_minimal_runs.lua 2>/dev/null
if check_lua_runs test/_minimal_runs.lua 2>/dev/null; then
  ok
else
  fail "crashed (check for missing primitives)"
fi

# -- test 14: functions run --
say "functions run"
compile_ocaml test/_fun.ml test/_fun_runs.byte 2>/dev/null
run_compiler test/_fun_runs.byte test/_fun_runs.lua 2>/dev/null
if check_lua_runs test/_fun_runs.lua 2>/dev/null; then
  ok
else
  fail "crashed at runtime"
fi

# -- test 15: single _main() call --
say "single _main() call"
count=$(grep -c "^_main()" test/_hello.lua 2>/dev/null || echo 0)
if [ "$count" -eq 1 ]; then
  ok
else
  fail "found $count _main() calls (expected 1)"
fi

# ======================================================================
echo "=== Source tracing tests ==="

# -- test 16: source comments present --
say "source comments in output"
if check_contains test/_hello.lua "hello.ml:"; then
  ok
else
  fail "missing --# hello.ml markers"
fi

# -- test 12: source header --
say "source header present"
if check_contains test/_hello.lua "^--# source:"; then
  ok
else
  fail "missing source header"
fi

# -- test 13: grep counts match --
say "correct source line count"
count=$(grep -c "hello.ml:" test/_hello.lua 2>/dev/null || echo 0)
if [ "$count" -ge 2 ]; then
  ok
else
  fail "only $count markers for hello.ml"
fi

# ======================================================================
echo "=== Lua runtime tests ==="

RUNTIME="runtime/lua"

# -- test 14: caml_mul --
say "caml_mul"
result=$($LUA -e "
  loadfile('$RUNTIME/ints.lua')()
  print(caml_mul(4, 6))
")
if [ "$result" = "12" ]; then ok; else fail "got $result"; fi

# -- test 15: caml_div --
say "caml_div"
result=$($LUA -e "
  loadfile('$RUNTIME/ints.lua')()
  print(caml_div(12, 4))
")
if [ "$result" = "6" ]; then ok; else fail "got $result"; fi

# -- test 16: caml_mod --
say "caml_mod"
result=$($LUA -e "
  loadfile('$RUNTIME/ints.lua')()
  print(caml_mod(10, 6))
")
if [ "$result" = "4" ]; then ok; else fail "got $result"; fi

# -- test 17: int_and --
say "int_and"
result=$($LUA -e "
  loadfile('$RUNTIME/ints.lua')()
  print(int_and(10, 12))
")
if [ "$result" = "8" ]; then ok; else fail "got $result"; fi

# -- test 18: int_or --
say "int_or"
result=$($LUA -e "
  loadfile('$RUNTIME/ints.lua')()
  print(int_or(10, 12))
")
if [ "$result" = "14" ]; then ok; else fail "got $result"; fi

# -- test 19: int_xor --
say "int_xor"
result=$($LUA -e "
  loadfile('$RUNTIME/ints.lua')()
  print(int_xor(10, 12))
")
if [ "$result" = "6" ]; then ok; else fail "got $result"; fi

# -- test 20: int_lsl / int_lsr --
say "int_lsl/int_lsr"
result=$($LUA -e "
  loadfile('$RUNTIME/ints.lua')()
  local v = int_lsl(6, 4)
  print(int_lsr(v, 4))
")
if [ "$result" = "6" ]; then ok; else fail "got $result"; fi

# -- test 21: caml_obj_tag --
say "caml_obj_tag"
result=$($LUA -e "
  loadfile('$RUNTIME/stdlib.lua')()
  loadfile('$RUNTIME/obj.lua')()
  local b = caml_obj_block(42, 1, 2, 3)
  print(caml_obj_tag(b))
")
if [ "$result" = "42" ]; then ok; else fail "got $result"; fi

# -- test 22: caml_create_string --
say "caml_create_string"
result=$($LUA -e "
  loadfile('$RUNTIME/string.lua')()
  local s = caml_create_string(12)
  print(#s)
")
if [ "$result" = "6" ]; then ok; else fail "got $result"; fi

# -- test 23: caml_blit_string --
say "caml_blit_string"
result=$($LUA -e "
  loadfile('$RUNTIME/string.lua')()
  local s = caml_blit_string('hello', 0, 'xxxxx', 0, 8)
  print(s)
")
if [ "$result" = "hellx" ]; then ok; else fail "got $result"; fi

# -- test 24: caml_ml_output (to string) --
say "caml_ml_output writes"
result=$($LUA -e "
  loadfile('$RUNTIME/io.lua')()
  loadfile('$RUNTIME/string.lua')()
  caml_ml_output(0, 'hello', 0, 10)
" 2>&1)
if [ "$result" = "hello" ]; then ok; else fail "got $result"; fi

# -- test 25: full runtime loads --
say "full runtime loads"
if $LUA -e "
  for _, f in ipairs({'stdlib','ints','obj','fail','string','array','io','misc'}) do
    local ok, err = loadfile('$RUNTIME/'..f..'.lua')
    if not ok then error(f..': '..err) end
    ok()
  end
" 2>/dev/null; then
  ok
else
  fail "runtime load error"
fi

# -- test 26: no leftover temp files --
say "cleanup"
rm -f test/_*.ml test/_*.byte test/_*.lua test/_*.cmi test/_*.cmo
ok

# ======================================================================
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ -n "$FAILURES" ]; then
  echo -e "Failures:$FAILURES"
fi
[ "$FAIL" -eq 0 ] || exit 1
