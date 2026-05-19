#include <caml/alloc.h>
#include <caml/mlvalues.h>

CAMLprim value ffi_external_add(value a, value b)
{
  return Val_int(Int_val(a) + Int_val(b));
}

CAMLprim value ffi_external_join(value a, value b)
{
  (void)a;
  (void)b;
  return caml_copy_string("");
}

CAMLprim value ffi_external_note(value s)
{
  (void)s;
  return Val_unit;
}

CAMLprim value ffi_external_last_note(value unit)
{
  (void)unit;
  return caml_copy_string("");
}

CAMLprim value ffi_external_call_cb(value cb, value x)
{
  (void)cb;
  return x;
}
