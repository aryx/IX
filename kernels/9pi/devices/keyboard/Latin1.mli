(* The characters made by the Alt key and two or three keys after it
 * (Plan 9's compose sequences; principia's latin1.c and its table,
 * latin1.h): Alt ' e is é, Alt * a is α, Alt X 2 0 a c is the
 * character of number 0x20ac. *)

(* the character of the keys typed after Alt (their numbers); -1 when
 * they make none; below -1 when more keys are needed *)
val latin1 : int list -> int
