#include <caml/mlvalues.h>
CAMLprim value rl_init_window(value a,value b,value c) { (void)a;(void)b;(void)c; return Val_unit; }
CAMLprim value rl_window_should_close(value v) { (void)v; return Val_bool(0); }
CAMLprim value rl_begin(value v) { (void)v; return Val_unit; }
CAMLprim value rl_end(value v) { (void)v; return Val_unit; }
CAMLprim value rl_clear(value a,value b,value c,value d) { (void)a;(void)b;(void)c;(void)d; return Val_unit; }
CAMLprim value rl_draw_rect(value a,value b,value c,value d,value e,value f,value g,value h) { (void)a;(void)b;(void)c;(void)d;(void)e;(void)f;(void)g;(void)h; return Val_unit; }
CAMLprim value rl_draw_text(value a,value b,value c,value d,value e,value f,value g,value h) { (void)a;(void)b;(void)c;(void)d;(void)e;(void)f;(void)g;(void)h; return Val_unit; }
CAMLprim value rl_is_key_down(value v) { (void)v; return Val_bool(0); }
