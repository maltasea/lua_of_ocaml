#!/bin/bash
# Audit primitives referenced by generated Lua against what the runtime
# provides.  Reports each name as IMPL (real implementation), STUB
# (defined but returns 0/empty), or MISSING (would resolve to the
# auto-stub when LOO_STRICT=0, or fail loudly when LOO_STRICT=1).
#
# Usage: ./misc/prim_inventory.sh [<bytecode-or-ml-file>]
#   (defaults to a small program that pulls in stdlib)
set -e
cd "$(dirname "$0")/.."

INPUT="$1"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/loo_prim_inv.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

if [ -z "$INPUT" ]; then
  cat > "$TMP/probe.ml" <<'EOF'
let () =
  print_endline "hello";
  print_int 42; print_newline ();
  Printf.printf "%d %s %.2f\n" 1 "x" 2.5;
  let a = [|1; 2; 3|] in
  Array.iter (fun n -> print_int n) a; print_newline ();
  let b = Buffer.create 8 in
  Buffer.add_string b "world";
  print_endline (Buffer.contents b)
EOF
  ocamlc -g -o "$TMP/probe.byte" "$TMP/probe.ml"
  INPUT="$TMP/probe.byte"
fi

case "$INPUT" in
  *.ml)
    ocamlc -g -o "$TMP/in.byte" "$INPUT"
    INPUT="$TMP/in.byte"
    ;;
esac

# Generate Lua for the program.
./loo.sh "$INPUT" "$TMP/out.lua" >/dev/null 2>&1 || {
  dune build >/dev/null 2>&1
  _build/default/compiler/bin-lua_of_ocaml/main.exe \
    --runtime runtime/lua "$INPUT" -o "$TMP/out.lua"
}

# Strip the runtime prefix so only program-emitted references appear.
RUNTIME_START=$(head -1 "$TMP/out.lua")
# Find where program code starts (after concatenated runtime).
awk '/^--# source:/ { in_prog=1 } in_prog { print }' "$TMP/out.lua" \
  > "$TMP/program.lua"
# Fallback: if no marker, use the full file.
[ -s "$TMP/program.lua" ] || cp "$TMP/out.lua" "$TMP/program.lua"

# Strip lua comments AND double-quoted string literals before scanning
# the program — both mention prim names that aren't real references.
sed 's|--.*||; s|"[^"]*"||g' "$TMP/program.lua" > "$TMP/program.nc.lua"

# All primitive-shaped names referenced by the program (calls or values).
# Filter:
#   * `_caml_exn` is a global variable, not a primitive
#   * names ending in `_NNNN` (e.g. `caml_special_val_13676`) are codegen-
#     suffixed OCaml-source names, not runtime primitives.
grep -oE '\bcaml_[a-zA-Z0-9_]+\b|\bdirect_obj_tag\b|\bint_[a-z_]+\b' "$TMP/program.nc.lua" \
  | grep -v '^_caml_exn$' \
  | grep -vE '_[0-9]+$' \
  | sort -u > "$TMP/refs.txt"

# Strip comments from runtime sources too before scanning for defs/stubs.
sed 's|--.*||' runtime/lua/*.lua > "$TMP/runtime.nc.lua"

# Names defined in the runtime.  Catches:
#   function name(...) ... end
#   name = anything    (assignments at line start OR after `;`)
#   name = other_name  (aliases)
{
  # function decls
  grep -oE '^function +[a-zA-Z_][a-zA-Z0-9_]+' "$TMP/runtime.nc.lua" \
    | sed -E 's/^function +//'
  # assignments anywhere — replace ; with newline first so multi-statement
  # lines (caml_and = int_and; caml_or = int_or; ...) get split.
  tr ';' '\n' < "$TMP/runtime.nc.lua" \
    | grep -oE '^ *[a-zA-Z_][a-zA-Z0-9_]+ *=' \
    | sed -E 's/^ *([a-zA-Z_][a-zA-Z0-9_]+) *=$/\1/'
} | grep -E '^(caml_|direct_obj_tag|int_)' \
  | sort -u > "$TMP/defs_all.txt"

# Stubs: defined as `function(...) return 0|{0}|""|nil end` (the auto-
# stub fallback shape).  Both block and inline forms.
{
  grep -hE 'function *\([^)]*\) +return +(0|\{0\}|"" *|nil) +end' "$TMP/runtime.nc.lua"
  awk '/= *function *\([^)]*\)/,/^end$/' "$TMP/runtime.nc.lua" \
    | awk 'BEGIN{name=""} /= *function *\(/ {name=$1} /return +(0|\{0\}|""|nil) *$/ && name {print name; name=""}'
} | grep -oE '^[a-zA-Z_][a-zA-Z0-9_]+' \
  | grep -E '^(caml_|direct_obj_tag|int_)' \
  | sort -u > "$TMP/stubs.txt"

echo "=== Primitive inventory for $(basename "$INPUT") ==="
echo
total=0; impl=0; stub=0; missing=0
while read -r name; do
  total=$((total+1))
  if grep -qx "$name" "$TMP/stubs.txt"; then
    printf "  STUB     %s\n" "$name"
    stub=$((stub+1))
  elif grep -qx "$name" "$TMP/defs_all.txt"; then
    impl=$((impl+1))
    # Don't print these; too noisy.
  else
    printf "  MISSING  %s\n" "$name"
    missing=$((missing+1))
  fi
done < "$TMP/refs.txt"

echo
echo "=== summary ==="
echo "  referenced: $total"
echo "  implemented: $impl"
echo "  stub-returns-0: $stub"
echo "  missing (auto-stubbed at runtime unless LOO_STRICT=1): $missing"
