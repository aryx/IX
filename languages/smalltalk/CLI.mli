(* mini-smalltalk: Smalltalk-80 from the Blue Book, with Squeak's
 * Morphic (docs/plans/plan_system_squeak.md), on a terminal: the system
 * brought up from its text or from an image, files of Smalltalk filed
 * in, expressions printed, the image saved, the Display written as a
 * picture. No window: Squeak's hosts are programs of their own. Its
 * usage: [help] in CLI.ml, what mini-smalltalk -h prints. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdin; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
