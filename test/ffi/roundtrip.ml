external lua_add : int -> int -> int = "lua_add"
external lua_greet : string -> string = "lua_greet"
external os_date : string -> string = "os_date"
let () = ignore (lua_add 10 20); ignore (lua_greet "hi"); ignore (os_date "%Y")
