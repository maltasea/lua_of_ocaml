-- raylib LuaJIT FFI bindings for lua_of_ocaml
local ffi = require("ffi")

ffi.cdef([[
  typedef struct { unsigned char r,g,b,a; } Color;
  void InitWindow(int w, int h, const char *title);
  void SetTargetFPS(int fps);
  bool WindowShouldClose(void);
  void BeginDrawing(void);
  void ClearBackground(Color color);
  void DrawRectangle(int x, int y, int w, int h, Color color);
  void DrawText(const char *text, int x, int y, int size, Color color);
  void EndDrawing(void);
  void CloseWindow(void);
  bool IsKeyDown(int key);
  int GetScreenWidth(void);
  int GetScreenHeight(void);
  int GetFPS(void);
]])

local rl = ffi.C

-- Wrappers callable from OCaml via external
function rl_init_window(w, h, title)
  rl.InitWindow(w, h, title)
  rl.SetTargetFPS(60)
end

function rl_window_should_close()
  return rl.WindowShouldClose()
end

function rl_begin_drawing()
  rl.BeginDrawing()
end

function rl_clear_bg(r, g, b, a)
  rl.ClearBackground({r=math.floor(r*255), g=math.floor(g*255),
                       b=math.floor(b*255), a=math.floor((a or 1)*255)})
end

function rl_draw_rect(x, y, w, h, r, g, b, a)
  rl.DrawRectangle(x, y, w, h,
    {r=math.floor(r*255), g=math.floor(g*255),
     b=math.floor(b*255), a=math.floor((a or 1)*255)})
end

function rl_draw_text(text, x, y, size, r, g, b, a)
  rl.DrawText(text, x, y, size,
    {r=math.floor(r*255), g=math.floor(g*255),
     b=math.floor(b*255), a=math.floor((a or 1)*255)})
end

function rl_end_drawing()
  rl.EndDrawing()
end

function rl_close_window()
  rl.CloseWindow()
end

function rl_is_key_down(key)
  return rl.IsKeyDown(key)
end

function rl_get_screen_w()
  return rl.GetScreenWidth()
end

function rl_get_screen_h()
  return rl.GetScreenHeight()
end

function rl_get_fps()
  return rl.GetFPS()
end

-- Keyboard constants
KEY_RIGHT = 262
KEY_LEFT  = 263
KEY_DOWN  = 264
KEY_UP    = 265
KEY_SPACE = 32
KEY_ESCAPE = 256
