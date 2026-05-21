# Microbenchmarks: lua_of_ocaml vs ocamlrun

`misc/bench.ml` is a small collection of tight-loop microbenchmarks.
Each is timed independently (`time prog`) and compared against the
same OCaml source running under `ocamlrun` (the OCaml bytecode
interpreter, *not* native `ocamlopt`).

Hardware: M1 mac, no special tuning.

| benchmark              | ocamlrun | luajit  | ratio    | what it tests |
|---|---:|---:|---:|---|
| `fib(30)`              | 0.04s   | 0.20s   | **5×**   | non-tail recursion |
| `sum_array(1M)`        | 0.05s   | 0.04s   | **0.7×** | for-loop + array write/read |
| `fold_list(200K)`      | 0.02s   | 0.08s   | **4×**   | tail-recursive list build + fold |
| `string_concat(100K)`  | 0.02s   | 0.14s   | **9×**   | Buffer.add_string in a loop |
| `map_ops(50K)`         | 0.10s   | 2.48s   | **25×**  | Map.Make + closures |
| `closure_calls(1M)`    | 0.04s   | 0.16s   | **4×**   | higher-order function call |

(Plain Lua 5.4 is uniformly another 3-5× slower than LuaJIT — LuaJIT's
trace JIT makes a huge difference on tight numeric loops.)

## Highlights

- **`sum_array` beats `ocamlrun`.** A pure for-loop with array
  reads/writes — no closures, no allocation — JITs well in LuaJIT
  and the bytecode interpreter has no edge.

- **`fib` and `closure_calls` are ~5× slower.** Every OCaml function
  call we don't know the arity of statically goes through
  `caml_call_gen`, which adds two table lookups (arity, weak cache)
  and a `select("#", ...)` per call. For exact applications that's
  pure overhead.

- **`Buffer.add_string` was catastrophically slow.** ~~The Bytes
  representation is `{ string }` — a single Lua-string wrapped in a
  table.  Every `Bytes.blit_string` (called by `Buffer.add_string`)
  rebuilds the entire dst string with `..` and `string.sub`.~~ FIXED:
  Bytes is now `{ chars_table }` where chars_table is a Lua array of
  byte values.  Every set/blit is O(len) instead of O(n).  Old 787×
  ratio dropped to 9×.

- **`Map.add` is 33× slower.** Map.Make is a heavy functor —
  pointer-chasing through tree nodes, all functions polymorphic
  (`caml_call_gen` per node access).

## Tail-call notes

~~We don't preserve tail calls~~ FIXED. `compile_block_no_loop` now
peeks at the block's last instruction and branch: when the pattern
is `Let (x, Apply { f; args; … }); Return x` we emit `return f(args)`
(or `return caml_call_gen(f, args)` for inexact applies).  Lua 5.1's
proper tail calls don't grow the C stack, so the canonical OCaml
tail pattern works through any depth.

```ocaml
let rec build acc i = if i = 0 then acc else build (i :: acc) (i - 1)
let xs = build [] 200_000  (* works *)
```

## What's worth optimising next

The remaining 4-25× ceiling comes from two sources, both of which
need compiler-side work rather than runtime tweaks:

1. **Polymorphic-call overhead via `caml_call_gen`**.  Map/Set
   internal traversal looks up the Ord-compare function from a
   record field per node, then calls it via `caml_call_gen`.
   `caml_call_gen` itself JITs fine in LuaJIT (measured at ~1.2 ns
   per call in a microbench), but the indirection blocks LuaJIT
   from inlining the compare body.  Fixing this needs IR-level
   arity propagation so more calls can be tagged `exact=true`.

2. **Per-node block allocation in functional data structures**.
   Every Map.add creates a fresh {0, l, k, v, r, h} table.  Lua
   table creation is intrinsically slower than OCaml runtime block
   allocation.  Would need either a different representation or
   in-runtime replacements for the hot Map/Set operations.

~~Tail-call codegen~~ and ~~Bytes/Buffer representation~~ are done.

## How to run

```
ocamlc -g -o /tmp/b.byte misc/bench.ml
./loo.sh misc/bench.ml /tmp/b.lua
time ocamlrun /tmp/b.byte
time luajit  /tmp/b.lua
```

The individual per-test split is in `misc/bench.ml`'s `time` wrapper,
but our runtime stubs `Sys.time` to 0 — use the shell `time` command
on per-test programs to get real numbers.
