(* a field of a type not in scope, its record's type not known: no
 * type to take the field from *)
module M = struct type t = { a : int } end
let f r = r.a
let _ = f
