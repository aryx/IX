(* A faster Arm32.execute for the instructions a kernel runs most,
 * written so that nothing is allocated. Those instructions are the
 * data-processing ones (except with a rotated operand, a shift by a
 * register, or an exception's return), the branches, and the block
 * transfers (except those with ^). Arm32's version makes two closures
 * at each data-processing instruction (logical and arith, a function
 * inside a function, which is simple to read) and a list at each block
 * load. Compiled to JavaScript, that was most of what the collector
 * had to take back (plan_web.md, stage 2). Every other instruction is
 * run by Arm32.execute, which stays the definition, and [on] chooses
 * between the two (Board.run). *)

val on : bool ref

val execute : Arm32_isa.state -> addr:int -> svc:(Arm32_isa.state -> int -> unit) -> Arm32_isa.t -> unit
