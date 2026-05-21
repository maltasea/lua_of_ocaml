# OCaml 5 effects in Lua, in one short file

OCaml 5 added effect handlers — a structured form of resumable
exceptions, well-suited for cooperative concurrency, async I/O, or
DSL interpreters. `js_of_ocaml`'s implementation took years to land
and is built on a whole-program CPS transformation.

In `lua_of_ocaml` (OCaml bytecode → Lua 5.1) we got there in
~90 lines of runtime code, no compiler-side changes. Here's how.

## The setup

```ocaml
open Effect
open Effect.Deep
type _ Effect.t += Get : int t

let () =
  let r =
    try_with (fun () -> 100 + perform Get) ()
      { effc = (fun (type a) (eff : a t) ->
          match eff with
          | Get -> Some (fun (k : (a, _) continuation) ->
              continue k 42)
          | _ -> None) }
  in
  print_int r  (* 142 *)
```

`perform Get` suspends the current computation. The handler runs,
receives the suspended `k`, and `continue k 42` resumes the body with
42 as the value of the `perform`.

`continue` and `discontinue` are how the handler resumes (or aborts)
the captured continuation.

## What jsoo does

jsoo's `--enable=effects` mode runs the program through a CPS
transformation: every function takes its continuation as an extra
argument. `perform` and `continue` become ordinary function calls on
those continuations. The runtime in `runtime/js/effect.js` is several
hundred lines, plus the transformation pass.

It works. But it's heavy, both implementation and runtime cost, and
you can't do it incrementally.

## The shortcut

Lua has native first-class **coroutines**. They are:

- exactly one-shot in practice (resume past completion errors out),
- first-class values you pass around in tables or as upvalues,
- not subject to the C call stack.

`coroutine.yield(v)` from inside a coroutine returns to the
`coroutine.resume(coro, …)` site with `v`. Subsequent resumes pass
values *back* to the yield site as its return value.

This is the API of one-shot continuations. So the mapping is:

| OCaml effects | Lua coroutines |
|---|---|
| `perform eff` | `coroutine.yield("perform", eff)` |
| `continue k v` | `coroutine.resume(coro, …)` causing the yield to return `v` |
| `discontinue k exn` | `coroutine.resume(coro, …)` causing the yield to raise `exn` |
| `(k : continuation)` | the coroutine itself (wrapped in a stack object) |

The last row is the punchline. We just identify OCaml's
`continuation` with the Lua coroutine that produced the
`perform` yield.

## The runtime

```lua
caml_current_stack = nil

function caml_alloc_stack(retc, exnc, effc)
  return { retc = retc, exnc = exnc, effc = effc,
           coro = nil, resumed = false }
end

function resume(stack, comp, arg, _last_fiber)
  local prev = caml_current_stack
  caml_current_stack = stack
  local ok, kind, val
  if stack.coro == nil then
    stack.resumed = true
    stack.coro = coroutine.create(function(initial_arg)
      local r = caml_call_gen(comp, initial_arg)
      return "complete", r
    end)
    ok, kind, val = coroutine.resume(stack.coro, arg)
  else
    if stack.resumed then
      caml_current_stack = prev
      error("Continuation_already_resumed")
    end
    stack.resumed = true
    ok, kind, val = coroutine.resume(stack.coro, comp, arg)
  end
  caml_current_stack = prev
  return _handle_yield(stack, ok, kind, val)
end

function perform(eff)
  if caml_current_stack == nil then
    error("Effect.Unhandled")
  end
  local comp, arg = coroutine.yield("perform", eff)
  return caml_call_gen(comp, arg)
end
```

`caml_alloc_stack` creates the "stack" — a handler triple plus a
lazily-created coroutine slot. `try_with f arg handler` (in OCaml
stdlib) allocates a stack and calls `resume(stack, f, arg, _)`.

On the first call, `resume` creates a coroutine that runs
`comp(initial_arg)`. The coroutine runs until it either returns
`("complete", value)` or yields `("perform", eff)`. The dispatcher:

```lua
local function _handle_yield(stack, ok, kind, val)
  if not ok then return caml_call_gen(stack.exnc, _caml_exn or kind) end
  if kind == "perform" then
    return caml_call_gen(stack.effc, val, stack, stack)
  end
  if kind == "complete" then
    return caml_call_gen(stack.retc, val)
  end
end
```

For `"perform"`, we hand the effect to `effc(eff, k, last_fiber)`,
passing the stack as the continuation. The handler may call
`continue k v` (routes back to `resume(stack, identity, v, _)`) or
`discontinue k exn` (routes back to `resume(stack, raise_fn, exn,_)`).

## The (comp, arg) trick

The non-obvious bit is what we pass back through the yield. We send
**two** values: a function `comp` and an argument `arg`. The yield
site evaluates `comp(arg)`.

- `continue k v`: `comp` is OCaml's identity (`fun v -> v`), `arg` is
  `v`. The yield returns `v`.
- `discontinue k exn`: `comp` is `fun e -> raise e`, `arg` is `exn`.
  The yield raises `exn` inside the body.

Both go through the same `coroutine.resume(stack.coro, comp, arg)`
path. Our runtime has one resume path, not two. The OCaml stdlib
does the discrimination for us:

```ocaml
let continue k v =
  match continuation_use k with
  | s -> caml_resume s (fun v -> v) v None

let discontinue k e =
  match continuation_use k with
  | s -> caml_resume s (fun e -> raise e) e None
```

We just honour that contract on the Lua side.

## What this costs

- `runtime/lua/effects.lua` is 93 lines including comments.
- No compiler-side changes. The IR already emits calls to
  `caml_alloc_stack`, `resume`, `perform`, `reperform`,
  `caml_continuation_use_noexc`, and
  `caml_continuation_use_and_update_handler_noexc` — that's all we
  needed to define.
- `test/behavioral/effects.ml` covers `continue`, chained `perform`s
  with state mutation in the handler, and `discontinue` raising into
  a `try/with` inside the body. All match `ocamlrun` byte-for-byte.

## Caveats

- **Performance**: each `perform` is a Lua coroutine yield, not a
  function call. For tight loops with frequent performs, this is
  slower than CPS. Fine for typical effect uses (interpreters,
  cooperative schedulers).
- **One-shot only**: OCaml effects are one-shot, and so is our
  implementation (calling `continue` twice on the same `k` raises
  `Continuation_already_resumed`). Multi-shot would need explicit
  coroutine cloning, which Lua doesn't have.
- **Stack depth**: nested handlers consume Lua C-stack frames. Hard
  to hit in normal code; possible to hit with deeply nested handler
  chains.

## Takeaway

If your target language has first-class coroutines, OCaml 5 effects
fall out almost for free. JavaScript doesn't have delimited
continuations (yet), so jsoo had to do CPS. Lua got there 25 years
ago.

I'm not the first to notice this — Racket's `call/cc`, Scheme's
delimited continuations, Stackless Python's tasklets all sit in the
same neighbourhood. But it's still pleasing to land it in one short
file of one runtime.

Source: <https://github.com/maltasea/lua_of_ocaml/blob/master/runtime/lua/effects.lua>
