(* 70b6b2bf, its fix: Bignum linked first (Early); and what must stay
 * quiet: a later unit named in a function its start does not call *)
let field = Early.of_int (1 lsl Early.base_bits)
let later () = Late.of_int 3

let () = print_int (List.length field)
