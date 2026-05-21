-- Headless harness for the example-game: mock love2d and step the
-- game loop a few frames.  Useful to verify the compiled OCaml runs
-- without needing the full LÖVE binary.
local last_print
love = {
  graphics = {
    print = function(s, x, y) last_print = s end,
    rectangle = function() end,
    setColor = function() end,
    getWidth = function() return 600 end,
    getHeight = function() return 400 end,
    clear = function() end,
    newFont = function() return {} end,
    setFont = function() end,
  },
  keyboard = { isDown = function(k) return k == "space" end },
  timer = { getDelta = function() return 0.016 end },
  event = { quit = function() end },
  window = {},
}

-- Load and run the compiled game.  This installs love.load/update/draw.
dofile("main.lua")

if love.load then love.load() end
for i = 1, 30 do
  if love.update then love.update(0.016) end
  if love.draw then love.draw() end
end
print("ok: ran 30 frames; HUD = " .. tostring(last_print))
