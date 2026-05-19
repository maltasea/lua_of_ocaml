-- love2d FFI binding tests (headless, no display needed)
dofile("../../runtime/lua/stdlib.lua")
dofile("../../runtime/lua/ints.lua")
dofile("../../runtime/lua/string.lua")

-- Mock love API so tests run without display
love = {
  graphics = {
    print = function() end,
    rectangle = function() end,
    setColor = function() end,
    getWidth = function() return 800 end,
    getHeight = function() return 600 end,
    clear = function() end,
    newFont = function() return {} end,
    setFont = function() end,
  },
  keyboard = { isDown = function() return false end },
  timer = { getDelta = function() return 0.016 end },
  event = { quit = function() end },
}

dofile("love_runtime.lua")

local pass, total = 0, 0
local function check(label, ok)
  total = total + 1
  if ok then pass = pass + 1; print("  OK: " .. label)
  else print("  FAIL: " .. label) end
end

print("=== Graphics ===")
check("lg_print", type(lg_print) == "function")
check("lg_rectangle", type(lg_rectangle) == "function")
check("lg_set_color", type(lg_set_color) == "function")
check("lg_get_width", lg_get_width() == 800)
check("lg_get_height", lg_get_height() == 600)
check("lg_clear", pcall(lg_clear, 0,0,0,1))
check("lg_set_font", pcall(lg_set_font, 14))

print("=== Input ===")
check("lk_is_down", type(lk_is_down) == "function")
check("lk_is_down false", lk_is_down("right") == false)

print("=== Timer ===")
check("lt_get_delta", type(lt_get_delta) == "function")
check("lt_get_delta > 0", lt_get_delta() > 0)

print("=== Events ===")
check("le_quit", type(le_quit) == "function")

print("=== Callbacks ===")
local up_dt = nil
local drew = false
_set_update(function(dt) up_dt = dt end)
_set_draw(function() drew = true end)
love.update(0.016)
love.draw()
check("update called", up_dt == 0.016)
check("draw called", drew == true)

print(string.format("\n%d/%d passed", pass, total))
if pass < total then os.exit(1) end
