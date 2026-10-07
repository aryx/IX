(* What mini-singml -safe refuses (tests/check.sh; tests/unsafe.expected). *)
let forge (n : int) : Sip.block = Obj.magic n
let () = Sip.free (forge 3)
