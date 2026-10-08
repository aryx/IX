(* What mini-singml -safe refuses (tests/check.sh; tests/unsafe.expected). *)
external peek : int -> int = "phys_get32"
let () = print_int (peek 0x8000)
