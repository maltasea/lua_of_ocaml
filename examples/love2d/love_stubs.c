#include <caml/mlvalues.h>
CAMLprim value lg_set_font(value v) { (void)v; return Val_unit; }
CAMLprim value lg_clear(value a,value b,value c,value d) { (void)a;(void)b;(void)c;(void)d; return Val_unit; }
CAMLprim value lg_set_color(value a,value b,value c,value d) { (void)a;(void)b;(void)c;(void)d; return Val_unit; }
CAMLprim value lg_rectangle(value a,value b,value c,value d,value e) { (void)a;(void)b;(void)c;(void)d;(void)e; return Val_unit; }
CAMLprim value lg_print(value a,value b,value c) { (void)a;(void)b;(void)c; return Val_unit; }
CAMLprim value _set_update(value v) { (void)v; return Val_unit; }
CAMLprim value _set_draw(value v) { (void)v; return Val_unit; }
CAMLprim value lt_get_delta(value v) { (void)v; return Val_unit; }
CAMLprim value lk_is_down(value v) { (void)v; return Val_bool(0); }
