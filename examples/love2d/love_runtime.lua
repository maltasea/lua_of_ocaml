local function ocaml_val(v)
  if type(v) == "number" then return v / 2 end
  if type(v) == "table" and v[1] == 253 then return v[2] or 0 end
  return v
end

function lg_print(text, x, y)
  love.graphics.print(text, ocaml_val(x), ocaml_val(y))
end
function lg_rectangle(mode, x, y, w, h)
  love.graphics.rectangle(mode, ocaml_val(x), ocaml_val(y), ocaml_val(w), ocaml_val(h))
end
function lg_set_color(r, g, b, a)
  love.graphics.setColor(ocaml_val(r), ocaml_val(g), ocaml_val(b), ocaml_val(a or 1))
end
function lg_get_width() return love.graphics.getWidth() * 2 end
function lg_get_height() return love.graphics.getHeight() * 2 end
function lk_is_down(key) return love.keyboard.isDown(key) end
function lt_get_delta() return love.timer.getDelta() end
function le_quit() love.event.quit() end
function lg_clear(r, g, b, a)
  love.graphics.clear(ocaml_val(r), ocaml_val(g), ocaml_val(b), ocaml_val(a or 1))
end
function lg_set_font(size)
  love.graphics.setFont(love.graphics.newFont(ocaml_val(size)))
end

local _update = nil
local _draw = nil
function _set_update(fn) _update = fn end
function _set_draw(fn) _draw = fn end

function love.load()
  love.graphics.setFont(love.graphics.newFont(14))
end

function love.update(dt)
  if _update then _update(dt) end
end

function love.draw()
  -- Always draw something so we know the game loop runs
  love.graphics.clear(0.2, 0.3, 0.5)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("LÖVE2D + OCaml FFI", 10, 10)
  love.graphics.setColor(0, 1, 0)
  love.graphics.rectangle("fill", 100, 100, 50, 50)
  -- Then call OCaml draw if registered
  if _draw then _draw() end
end

function love.keypressed(key)
  if key == "escape" then love.event.quit() end
end
