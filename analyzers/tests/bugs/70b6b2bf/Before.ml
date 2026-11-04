(* 70b6b2bf^, lib_crypto/Poly1305.ml: its field made at its start from
 * Bignum's limb width, Bignum linked after it (the mkfiles' order):
 * base_bits 0 when it was read, the program did not start *)
let limbs () = List.length (Late.of_int 5)
let field = Late.of_int (1 lsl Late.base_bits)
let width = limbs ()

let () = print_int (List.length field + width)
