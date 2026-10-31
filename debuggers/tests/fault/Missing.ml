(* a Unix_error not caught (debuggers/tests/walk.sh): Unix's printer
 * says the error by its message, the kernel's on Plan 9 *)
let () = ignore (Unix.openfile "/no/such/file" [ Unix.O_RDONLY ] 0)
