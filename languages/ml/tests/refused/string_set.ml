(* a string is not written: bytes are *)
let () = let s = "abc" in Bytes.set s 0 'z'; print_string s
