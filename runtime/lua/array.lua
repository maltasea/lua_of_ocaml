-- lua_of_ocaml runtime: array and vector operations
-- Provides: caml_vect_length caml_array_get caml_array_set
--           caml_array_unsafe_get caml_array_unsafe_set

local math_floor = math.floor

function caml_vect_length(v) return (#v - 1) * 2 end
function caml_array_get(v, i) return v[math_floor(i / 2) + 2] or 0 end
function caml_array_set(v, i, x) v[math_floor(i / 2) + 2] = x; return 0 end
function caml_array_unsafe_get(v, i) return caml_array_get(v, i) end
function caml_array_unsafe_set(v, i, x) return caml_array_set(v, i, x) end
