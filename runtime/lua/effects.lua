-- lua_of_ocaml runtime: OCaml 5 effect handlers via Lua coroutines.
--
-- jsoo implements effects through a whole-program CPS transformation;
-- here we use Lua's native coroutines, which give us one-shot
-- continuations directly.  This works because Effect.continue is
-- one-shot in OCaml too (calling continue twice raises
-- Continuation_already_resumed).
--
-- Stack object (returned by caml_alloc_stack and used as the
-- continuation k):
--   { retc, exnc, effc, coro, resumed }
-- coro is created on the first resume.

caml_current_stack = nil

function caml_alloc_stack(retc, exnc, effc)
  return { retc = retc, exnc = exnc, effc = effc, coro = nil, resumed = false }
end

local function _handle_yield(stack, ok, kind, val)
  if not ok then
    -- Lua-level error inside the coroutine.
    local exn = _caml_exn or kind
    return caml_call_gen(stack.exnc, exn)
  end
  if kind == "perform" then
    -- Effect performed.  Hand it to effc(eff, k, last_fiber).
    return caml_call_gen(stack.effc, val, stack, stack)
  end
  if kind == "complete" then
    return caml_call_gen(stack.retc, val)
  end
  -- Coroutine returned plainly (no explicit yield/return marker).
  return caml_call_gen(stack.retc, kind)
end

-- resume(stack, comp, arg, last_fiber)
--   First call (stack.coro nil): starts comp(arg) in a new coroutine.
--   Subsequent calls (continue/discontinue): comp is a transform to
--   apply at the perform yield site.  For continue: comp = identity
--   so perform returns arg.  For discontinue: comp = (fun e -> raise e)
--   so perform raises arg.
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

-- perform(eff): yield the effect; on resume, apply comp(arg).
function perform(eff)
  if caml_current_stack == nil then
    error("Effect.Unhandled")
  end
  local comp, arg = coroutine.yield("perform", eff)
  return caml_call_gen(comp, arg)
end

function reperform(eff, _k, _last_fiber)
  return perform(eff)
end

function caml_continuation_use_noexc(k)
  -- Return the underlying stack so callers can pass it to resume.
  -- We also mark the continuation as "not yet resumed again" so the
  -- next resume call goes through.
  k.resumed = false
  return k
end

function caml_continuation_use_and_update_handler_noexc(k, retc, exnc, effc)
  k.retc = retc
  k.exnc = exnc
  k.effc = effc
  k.resumed = false
  return k
end
