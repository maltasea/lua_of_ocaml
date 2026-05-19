ffi_external_notes = {}

function ffi_external_add(a, b)
  return a + b
end

function ffi_external_join(a, b)
  return a .. ":" .. b
end

function ffi_external_note(s)
  ffi_external_notes[#ffi_external_notes + 1] = s
  return 0
end

function ffi_external_last_note(_unit)
  return ffi_external_notes[#ffi_external_notes] or ""
end

function ffi_external_call_cb(cb, x)
  return cb(x)
end
