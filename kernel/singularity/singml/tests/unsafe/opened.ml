(* What mini-singml -safe refuses (tests/check.sh; tests/unsafe.expected). *)
open Marshal
let () = print_int Array.(unsafe_get [| 1 |] 5)
