(* What mini-singml -safe refuses (tests/check.sh; tests/unsafe.expected). *)
let () = print_char (String.unsafe_get "abc" 100000)
