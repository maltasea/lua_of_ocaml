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
| `string_concat(100K)`  | 0.02s   | 12.59s  | **787×** | Buffer.add_string in a loop |
| `map_ops(50K)`         | 0.10s   | 3.43s   | **33×**  | Map.Make + closures |
| `closure_calls(1M)`    | 0.04s   | 0.18s   | **5×**   | higher-order function call |

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

- **`Buffer.add_string` is catastrophically slow.** The Bytes
  representation is `{ string }` — a single Lua-string wrapped in a
  table. Every `Bytes.blit_string` (called by `Buffer.add_string`)
  rebuilds the entire dst string with `..` and `string.sub`. Over
  100K iterations of 3-char appends, that's roughly *O(n²)* work.

- **`Map.add` is 33× slower.** Map.Make is a heavy functor —
  pointer-chasing through tree nodes, all functions polymorphic
  (`caml_call_gen` per node access).

## Tail-call notes

OCaml's bytecode compiler emits `TAILCALL` for syntactic tail
positions; `ocamlrun` honours it. **We don't.** Every `branch ~f x`
in our codegen is a regular Lua call, consuming a C-stack frame.

LuaJIT's `lua_resume` C stack is ~2000 frames before overflow. So
any OCaml program that recurses tail-style beyond that depth crashes:

```ocaml
let rec build acc i = if i = 0 then acc else build (i :: acc) (i - 1)
let xs = build [] 200_000  (* boom *)
```

`Array.to_list` from the stdlib is also tail-recursive in OCaml; it
overflows here at the same depth.

This is the single biggest correctness gap. Two ways out:

1. **Trampolining**: every function returns `(continue?, fn, args)`;
   a top-level driver loop invokes them. Adds overhead to every
   call but caps stack usage.

2. **Tail-call detection in codegen**: emit `return foo(...)` where
   the IR shows a tail position. Lua 5.1's "proper tail calls" via
   `return f(x)` do *not* grow the stack. This is the right answer
   but requires control-flow analysis in `compile_branch`.

## What's worth optimising

In rough order of pain-per-line-of-fix:

1. **Bytes/Buffer representation** (fixes the 787× regression).
   Change `Bytes.t` from `{ string }` to `{ chars_table, length }`
   where `chars_table` is a Lua table of byte values. Every
   `caml_bytes_get/set/blit` becomes O(1)/O(len) amortised.
   Buffer.add_char trivially fast.

2. **Tail-call codegen** (fixes correctness for deep recursion).
   Detect IR tail positions, emit `return f(args)`.

3. **Specialised `caml_call_gen` for exact-arity calls** (helps fib,
   closure_calls). Most calls are exact; emit them as direct Lua
   calls without the arity-table lookup. We already do this when
   the IR says `exact = true` — the question is whether more sites
   in the IR could be tagged exact than currently are.

4. **Map/Set/Hashtbl runtime helpers**. Reimplement the hot ones
   (find, add, mem) in Lua native code instead of going through
   OCaml's purely-functional tree per node.

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
