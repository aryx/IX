(* Faster: Arm32.execute for the instructions a kernel runs most, the
 * data-processing ones (but a rotated operand, a shift by a register,
 * an exception's return), the branches and the block transfers (but
 * those with ^), written so that nothing is allocated: Arm32's makes
 * two closures at each data-processing instruction (logical, arith: a
 * function inside a function, simple to read) and a list at each
 * block load. Every other instruction is Arm32.execute's. Compiled to
 * JavaScript that is most of what the collector had to take back
 * (plan_web.md, stage 2); Arm32.execute stays the definition, and
 * [on] chooses (Board.run). *)

val on : bool ref

val execute : Arm32_isa.state -> addr:int -> svc:(Arm32_isa.state -> int -> unit) -> Arm32_isa.t -> unit
