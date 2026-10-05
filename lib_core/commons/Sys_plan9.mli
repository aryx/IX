(* Plan 9's own, for a program of ix's that also runs there
 * ([Sys.os_type] is "Plan9": plan_rio.md): what OCaml's Unix has no
 * name for. Two files: this directory's, for every other system, where
 * each function has nothing to say; and ../system/plan9/'s, Plan 9's
 * (mkfiles/mkconfig's UNIXDIR). *)

(* a child waited for (its pid): its last words as the kernel gives
 * them ("ls 12: no such file"), which rc keeps as $status; "" when it
 * had none, and on another system *)
val last_words : int -> string
