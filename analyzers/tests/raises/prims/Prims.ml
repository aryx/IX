(* externals of prims.c: said right (my_open, my_parse through failwith),
 * not said (my_find, my_rename through a wrapper), said wrong (my_len) *)
external my_open : int -> int = "my_open" [@@raise Sys_error]
external my_find : int -> int = "my_find"
external my_len : int -> int = "my_len" [@@raise Sys_error]
external my_parse : int -> int = "my_parse" [@@raise Failure]
external my_rename : int -> int = "my_rename"

let () = print_int (my_open 1 + my_find 1 + my_len 1 + my_parse 1 + my_rename 1)
