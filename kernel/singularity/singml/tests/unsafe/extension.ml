(* What mini-singml -safe refuses (tests/check.sh; tests/unsafe.expected). *)
let f (x : int) : int = [%bits "x"]
