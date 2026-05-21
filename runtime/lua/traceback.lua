-- lua_of_ocaml runtime: source-mapped tracebacks.
--
-- Generated Lua files are huge (often 50K+ lines), so a raw Lua stack
-- trace like `file.lua:24813: …` is useless for finding the bug in
-- the original OCaml.  generate_lua.ml emits `--# <file>:<line>`
-- markers right before each translated instruction, so we can map a
-- Lua line back to its OCaml origin.
--
-- This module builds that map lazily on the first error and wraps
-- the running script's traceback.

local _src_map = nil  -- lua_line -> "file:line" (OCaml)

local function build_src_map()
  local info = debug.getinfo(1, "S")
  local src = info and info.source or ""
  if src:sub(1, 1) ~= "@" then return {} end  -- not file-backed
  local path = src:sub(2)
  local f = io.open(path, "r")
  if not f then return {} end
  local map = {}
  local i = 0
  local last = nil
  for line in f:lines() do
    i = i + 1
    -- markers look like:  -- # file.ml:42
    local file, ln = line:match("^%s*%-%-%s*#%s*(.-):(%d+)")
    if file and ln then
      last = file .. ":" .. ln
    elseif last then
      map[i] = last
    end
  end
  f:close()
  return map
end

local function ensure_map()
  if _src_map == nil then _src_map = build_src_map() end
  return _src_map
end

-- Look up an OCaml location for a given Lua line.  Returns nil if no
-- marker has been emitted by that point in the file.
function caml_lookup_src(lua_line)
  return ensure_map()[lua_line]
end

-- Augment a Lua traceback by appending OCaml source locations to
-- every `…:N:` reference whose mapped position is known.
function caml_augment_traceback(tb)
  local map = ensure_map()
  if next(map) == nil then return tb end
  return tb:gsub("(%S+):(%d+):", function(file, line)
    local ln = tonumber(line)
    local ocaml = map[ln]
    if ocaml then
      return file .. ":" .. line .. " [" .. ocaml .. "]:"
    end
    return file .. ":" .. line .. ":"
  end)
end

-- Walk up the Lua stack and find the deepest frame whose Lua line
-- has an OCaml source mapping.  Returns "file:line" or nil.
local function deepest_ocaml_frame()
  local map = ensure_map()
  local level = 2
  while true do
    local info = debug.getinfo(level, "Sl")
    if not info then return nil end
    if info.currentline and info.currentline > 0 then
      local at = map[info.currentline]
      if at then return at end
    end
    level = level + 1
  end
end

-- Top-level error handler.  Installed via xpcall around _main.
function caml_top_traceback(err)
  local head = tostring(err)
  local at = deepest_ocaml_frame()
  if at then head = head .. "\n  in " .. at end
  local tb = debug.traceback("", 2)
  return head .. "\n" .. caml_augment_traceback(tb)
end
