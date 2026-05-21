#!/bin/bash
# Behavioral tests: compare OCaml bytecode output vs generated Lua output
set -e
cd "$(dirname "$0")/../.."

LUA=${LUA:-lua}
# Strict mode by default — see test/run_all.sh.
export LOO_STRICT=${LOO_STRICT:-1}
PASS=0; FAIL=0; XFAIL=0; XPASS=0; SKIP=0
TMP=test/_out; rm -rf $TMP; mkdir -p $TMP

# Detect OCaml major.minor for version-gating tests (effect handlers
# need 5.0+).
OCAML_VERSION=$(ocamlc -version 2>/dev/null | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
ocaml_ge_5() {
  case "$OCAML_VERSION" in
    5.*) return 0;;
    *)   return 1;;
  esac
}

say()    { printf "  %-45s" "$1"; }
ok()     { echo " OK"; PASS=$((PASS+1)); }
fail()   { echo " FAIL ($1)"; FAIL=$((FAIL+1)); }
xfail()  { echo " XFAIL (known broken)"; XFAIL=$((XFAIL+1)); }
xpass()  { echo " XPASS (fixed! flip to compare)"; XPASS=$((XPASS+1)); }
skip()   { echo " SKIP ($1)"; SKIP=$((SKIP+1)); }

_run_both() {
  local name="$1" src="test/behavioral/$2"
  ocamlc -g -o $TMP/"$name".byte "$src" 2>/dev/null || return 1
  ocamlrun $TMP/"$name".byte > $TMP/"$name".ocaml_out 2>&1 || true
  dune exec -- compiler/bin-lua_of_ocaml/main.exe -- $TMP/"$name".byte -o $TMP/"$name".lua 2>/dev/null || return 2
  $LUA $TMP/"$name".lua > $TMP/"$name".lua_out 2>&1 || true
}

compare() {
  local name="$1" src="$2"
  say "$name"
  _run_both "$name" "$src"
  case $? in
    1) fail "ocamlc"; return;;
    2) fail "compiler"; return;;
  esac
  if diff -q $TMP/"$name".ocaml_out $TMP/"$name".lua_out >/dev/null 2>&1; then
    ok
  else
    local ocaml_out=$(cat $TMP/"$name".ocaml_out 2>/dev/null | tr '\n' ' ')
    local lua_out=$(cat $TMP/"$name".lua_out 2>/dev/null | tr '\n' ' ')
    fail "ocaml[$ocaml_out] != lua[$lua_out]"
  fi
}

# Expected-fail: documents a known-broken case.  Logged as XFAIL when still
# broken (does not fail the suite), as XPASS when it starts matching (a
# nudge to flip the test back to `compare` and remove this entry).
xfail_compare() {
  local name="$1" src="$2"
  say "$name"
  _run_both "$name" "$src"
  case $? in
    1) fail "ocamlc"; return;;
    2) fail "compiler"; return;;
  esac
  if diff -q $TMP/"$name".ocaml_out $TMP/"$name".lua_out >/dev/null 2>&1
  then xpass
  else xfail
  fi
}

echo "=== Behavioral Tests ==="
compare "hello"        "hello.ml"
compare "arith"        "arith.ml"
compare "strings"      "strings.ml"
compare "functions"    "functions.ml"
compare "comparison"   "comparison.ml"
compare "bools"        "bools.ml"
compare "arrays"       "arrays.ml"
compare "floats"       "floats.ml"
compare "structural_eq" "structural_eq.ml"
compare "bytes_loop"   "bytes_loop.ml"
compare "options"      "options.ml"
compare "higher_order" "higher_order.ml"
compare "buffer"       "buffer.ml"
compare "printf_single" "printf_single.ml"
compare "printf_multi" "printf_multi.ml"
compare "polyvariants" "polyvariants.ml"
compare "modules"      "modules.ml"
compare "firstclass"   "firstclass.ml"
compare "gadt"         "gadt.ml"

compare "objects"      "objects.ml"
if ocaml_ge_5; then
  compare "effects"      "effects.ml"
else
  say "effects"; skip "needs OCaml 5+"
fi
compare "json"         "json.ml"
compare "hashtbl"      "hashtbl.ml"

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $XFAIL xfail, $XPASS xpass, $SKIP skipped ==="
if [ "$XPASS" -gt 0 ]; then
  echo "(XPASS = previously known-broken test now passes — flip it to compare.)"
fi
[ "$FAIL" -eq 0 ] || exit 1
