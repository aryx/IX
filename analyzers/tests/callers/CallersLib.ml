(* mini-analyze -dead on a library given alone: its programs found
 * (Caller_finder), CallersA and CallersB, each read, and what every one
 * of them says kept *)

(* each called by one program: not dead *)
let by_a x = x + 1
let by_b x = x + 2

(* both call it *)
let by_both x = x + 3

(* no program calls it: dead *)
let by_none x = x + 4
