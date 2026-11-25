(* a toplevel's globals read where they are defined: limit by a
 * primitive (=) that moves no value, not dead; unread read only by a
 * dead function, dead *)
let limit = 1 + 2
let () = if limit = 0 then exit 1

let unread = 4 + 5
let never () = unread = 0
