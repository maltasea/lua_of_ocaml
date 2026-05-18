let () =
  let r = try failwith "boom" with Failure _ -> 42 in
  ignore r
