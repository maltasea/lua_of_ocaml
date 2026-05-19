-- LÖVE2D FFI wrappers for lua_of_ocaml
-- Each function here is callable from OCaml via external declarations.

function lg_print(text, x, y)
  love.graphics.print(text, x, y)
end

function lg_rectangle(mode, x, y, w, h)
  love.graphics.rectangle(mode, x, y, w, h)
end

function lg_set_color(r, g, b, a)
  love.graphics.setColor(r, g, b, a or 1)
end

function lg_get_width()
  return love.graphics.getWidth()
end

function lg_get_height()
  return love.graphics.getHeight()
end

function lk_is_down(key)
  return love.keyboard.isDown(key)
end

function lt_get_delta()
  return love.timer.getDelta()
end

function le_quit()
  love.event.quit()
end

function lg_clear(r, g, b, a)
  love.graphics.clear(r, g, b, a or 1)
end

function lg_set_font(size)
  love.graphics.setFont(love.graphics.newFont(size))
end

-- Stored callbacks, called from OCaml at init time
local _update = nil
local _draw = nil

function _set_update(fn) _update = fn end
function _set_draw(fn) _draw = fn end

function love.update(dt)
  if _update then _update(dt) end
end

function love.draw()
  if _draw then _draw() end
end

function love.load()
  -- OCaml _main() sets up callbacks via _set_update/_set_draw
end

function love.keypressed(key)
  if key == "escape" then love.event.quit() end
end
