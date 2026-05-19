-- raylib LuaJIT FFI bindings for lua_of_ocaml
local ffi = require("ffi")

ffi.cdef([[
  typedef struct { unsigned char r,g,b,a; } Color;
  typedef struct { float x, y; } Vector2;
  typedef struct { float x, y, width, height; } Rectangle;
  void InitWindow(int w, int h, const char *title);
  void CloseWindow(void);
  bool WindowShouldClose(void);
  void BeginDrawing(void);
  void ClearBackground(Color);
  void DrawRectangle(int x, int y, int w, int h, Color);
  void DrawCircle(int cx, int cy, float r, Color);
  void DrawText(const char *text, int x, int y, int size, Color);
  void EndDrawing(void);
  void SetTargetFPS(int);
  int GetFPS(void);
  int GetScreenWidth(void);
  int GetScreenHeight(void);
  float GetFrameTime(void);
  bool IsKeyDown(int);
  bool IsKeyPressed(int);
  bool IsKeyReleased(int);
  int GetKeyPressed(void);
]])

local rl = ffi.C

local function ocaml_to_color(r, g, b, a)
  if type(r) == "table" and r[1] == 253 then r = r[2] or 0 end
  if type(r) == "number" then r = r / 2 end
  if type(g) == "table" and g[1] == 253 then g = g[2] or 0 end
  if type(g) == "number" then g = g / 2 end
  if type(b) == "table" and b[1] == 253 then b = b[2] or 0 end
  if type(b) == "number" then b = b / 2 end
  if type(a) == "table" and a[1] == 253 then a = a[2] or 0 end
  if type(a) == "number" then a = a / 2 end
  return ffi.new("Color", math.floor(r*255), math.floor(g*255), math.floor(b*255), math.floor((a or 1)*255))
end

local function ocaml_int(v)
  if type(v) == "number" then return math.floor(v / 2) end
  return v or 0
end

local function ocaml_float(v)
  if type(v) == "table" and v[1] == 253 then return v[2] or 0 end
  if type(v) == "number" then return v / 2 end
  return v or 0
end

-- Wrappers callable from OCaml via external
function rl_init_window(w, h, title) rl.InitWindow(ocaml_int(w), ocaml_int(h), title); rl.SetTargetFPS(60) end
function rl_close_window() rl.CloseWindow() end
function rl_window_should_close() return rl.WindowShouldClose() end
function rl_begin() rl.BeginDrawing() end
function rl_end() rl.EndDrawing() end
function rl_clear(r, g, b, a) rl.ClearBackground(ocaml_to_color(r, g, b, a)) end

function rl_draw_rect(x, y, w, h, r, g, b, a)
  rl.DrawRectangle(ocaml_int(x), ocaml_int(y), ocaml_int(w), ocaml_int(h), ocaml_to_color(r, g, b, a))
end

function rl_draw_circle(cx, cy, radius, r, g, b, a)
  rl.DrawCircle(ocaml_int(cx), ocaml_int(cy), ocaml_float(radius), ocaml_to_color(r, g, b, a))
end

function rl_draw_text(text, x, y, size, r, g, b, a)
  rl.DrawText(text, ocaml_int(x), ocaml_int(y), ocaml_int(size), ocaml_to_color(r, g, b, a))
end

function rl_is_key_down(key) return rl.IsKeyDown(ocaml_int(key)) end
function rl_get_fps() return rl.GetFPS() * 2 end
function rl_get_screen_w() return rl.GetScreenWidth() * 2 end
function rl_get_screen_h() return rl.GetScreenHeight() * 2 end
function rl_get_frame_time() return rl.GetFrameTime() end

-- Key constants (tagged for OCaml)
KEY_RIGHT  = 262 * 2
KEY_LEFT   = 263 * 2
KEY_DOWN   = 264 * 2
KEY_UP     = 265 * 2
KEY_SPACE  = 32 * 2
KEY_ESCAPE = 256 * 2
KEY_A      = 65 * 2
KEY_D      = 68 * 2
KEY_W      = 87 * 2
KEY_S      = 83 * 2
