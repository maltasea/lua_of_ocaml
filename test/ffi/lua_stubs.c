#include <caml/mlvalues.h>
CAMLprim value lua_add(value a, value b) { (void)a; (void)b; return Val_int(0); }
CAMLprim value lua_greet(value s) { (void)s; return Val_int(0); }
CAMLprim value os_date(value s) { (void)s; return Val_int(0); }
