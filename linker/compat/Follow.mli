(* 5l's and 7l's follow (xfol): the code in the order its flow goes,
 * a conditional branch inverted when that makes its target the next
 * instruction, a short run that ends the flow copied instead of a
 * branch to it, and the dead code dropped. It is how 5l and 7l lay the
 * code out, so mini-ld's executables are goken's byte for byte with it
 * (the default); it changes no program's behavior, and mini-ld
 * -nofollow keeps the code in the objects' order. [ends]: the
 * machine's, what ends the flow (a B, a RET).
 *
 * References: Ken Thompson, "Plan 9 C Compilers", section "The
 * loader": code "reordered to remove unconditional branch
 * instructions", conditional branches inverted, and a few instructions
 * copied instead of a branch. *)

val follow : 'm Link.t -> ends:('m Link.prog -> bool) -> unit
