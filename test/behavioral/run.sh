#!/bin/bash
# Behavioral tests: compare OCaml bytecode output vs generated Lua output
set -e
cd "$(dirname "$0")/../.."

LUA=${LUA:-lua}
PASS=0; FAIL=0
TMP=test/_out; rm -rf $TMP; mkdir -p $TMP

say()  { printf "  %-45s" "$1"; }
ok()   { echo " OK"; PASS=$((PASS+1)); }
fail() { echo " FAIL ($1)"; FAIL=$((FAIL+1)); }

compare() {
  local name="$1" src="test/behavioral/$2"
  say "$name"

  # Compile OCaml, run with ocamlrun
  ocamlc -g -o $TMP/"$name".byte "$src" 2>/dev/null || { fail "ocamlc"; return; }
  ocamlrun $TMP/"$name".byte > $TMP/"$name".ocaml_out 2>&1 || true

  # Compile to Lua, run
  dune exec -- compiler/bin-lua_of_ocaml/main.exe -- $TMP/"$name".byte -o $TMP/"$name".lua 2>/dev/null || { fail "compiler"; return; }
  $LUA $TMP/"$name".lua > $TMP/"$name".lua_out 2>&1 || true

  # Compare
  if diff -q $TMP/"$name".ocaml_out $TMP/"$name".lua_out >/dev/null 2>&1; then
    ok
  else
    local ocaml_out=$(cat $TMP/"$name".ocaml_out 2>/dev/null | tr '\n' ' ')
    local lua_out=$(cat $TMP/"$name".lua_out 2>/dev/null | tr '\n' ' ')
    fail "ocaml[$ocaml_out] != lua[$lua_out]"
  fi
}

echo "=== Behavioral Tests ==="
compare "hello"      "hello.ml"
compare "arith"      "arith.ml"
compare "strings"    "strings.ml"
compare "functions"  "functions.ml"
compare "comparison" "comparison.ml"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
