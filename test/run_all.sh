#!/bin/bash
# lua_of_ocaml full test suite
set -e
cd "$(dirname "$0")/.."
LUA=${LUA:-lua}
TMP=test/_out; rm -rf $TMP; mkdir -p $TMP
PASS=0; FAIL=0

say()  { printf "  %-55s" "$1"; }
ok()   { echo " OK"; PASS=$((PASS+1)); }
fail() { echo " FAIL ($1)"; FAIL=$((FAIL+1)); }

compile_test() {
  local name="$1" src="test/$2"
  say "$name"
  local fname=$(echo "$name" | tr '/' '_')
  ocamlc -g -o $TMP/"$fname".byte "$src" 2>/dev/null || { fail "ocamlc"; return 1; }
  dune exec -- compiler/bin-lua_of_ocaml/main.exe -- $TMP/"$fname".byte -o $TMP/"$fname".lua 2>/dev/null || { fail "compiler"; return 1; }
  $LUA -e "assert(loadfile('$TMP/${fname}.lua'))" 2>/dev/null || { fail "syntax"; return 1; }
  ok
}

run_test() {
  local name="$1" src="test/$2"
  say "$name (run)"
  local fname=$(echo "$name" | tr '/' '_')
  ocamlc -g -o $TMP/"$fname".byte "$src" 2>/dev/null || { fail "ocamlc"; return 1; }
  dune exec -- compiler/bin-lua_of_ocaml/main.exe -- $TMP/"$fname".byte -o $TMP/"$fname".lua 2>/dev/null || { fail "compiler"; return 1; }
  $LUA $TMP/"$fname".lua >/dev/null 2>&1 || { fail "runtime"; return 1; }
  ok
}

lua_test() {
  local name="$1" file="$2"
  say "$name"
  $LUA "$file" 2>&1 >/dev/null || { fail "lua"; return 1; }
  ok
}

ffi_roundtrip() {
  say "ffi/roundtrip"
  ${MAKE:-make} -C test/ffi roundtrip LUA="$LUA" >/dev/null 2>&1 || { fail "roundtrip"; return 1; }
  ok
}

echo "=== Compiler Tests ==="
build() { dune build 2>/dev/null; }; build
compile_test "smoke/hello"        "smoke/hello.ml"
compile_test "compiler/arith"     "compiler/arith.ml"
compile_test "compiler/strings"   "compiler/strings.ml"
compile_test "compiler/functions" "compiler/functions.ml"
compile_test "compiler/recursion" "compiler/recursion.ml"
compile_test "compiler/closures"  "compiler/closures.ml"
compile_test "compiler/match"     "compiler/pattern_match.ml"
compile_test "compiler/lists"     "compiler/lists.ml"
compile_test "compiler/exceptions" "compiler/exceptions.ml"
compile_test "compiler/tuples"    "compiler/tuples.ml"
compile_test "compiler/int_ops"   "compiler/int_ops.ml"
compile_test "compiler/float"     "compiler/float.ml"

echo "=== Runtime Smoke Tests ==="
run_test "smoke/hello"  "smoke/hello.ml"
run_test "arith"        "compiler/arith.ml"
run_test "functions"    "compiler/functions.ml"
run_test "exceptions"   "compiler/exceptions.ml"

echo "=== Lua Runtime Tests ==="
lua_test "runtime/ints"   "test/runtime/ints_test.lua"
lua_test "runtime/string" "test/runtime/string_test.lua"
lua_test "runtime/obj"    "test/runtime/obj_test.lua"

echo "=== FFI Tests ==="
ffi_roundtrip
lua_test "ffi/runtime" "test/ffi/ffi_test.lua"

echo "=== Source Tracing ==="
say "source header present"
grep -q "^--# source:" $TMP/smoke_hello.lua 2>/dev/null && ok || fail "missing"

say "source comment count"
count=$(grep -c "hello.ml:" $TMP/smoke_hello.lua 2>/dev/null || echo 0)
[ "$count" -ge 1 ] && ok || fail "got $count"

say "single _main()"
count=$(grep -c "^_main()" $TMP/smoke_hello.lua 2>/dev/null || echo 0)
[ "$count" -eq 1 ] && ok || fail "got $count"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
