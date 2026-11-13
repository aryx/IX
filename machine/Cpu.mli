(* The loop: fetch, decode, execute. An instruction is decoded only
 * once, because a direct-mapped cache keeps the decoded instructions by
 * their address (plan_arm.md, decision 5).
 *
 * A processor is this loop in silicon, and an interpreter is the
 * loop written down:
 *
 *     forever:
 *       word  = memory[pc]            fetch
 *       instr = decode word           finds the instruction and its
 *                                     fields
 *       execute instr                 changes the registers, the flags
 *                                     and the memory
 *       pc    = the next one          pc + 4, or where a branch says
 *
 * Decoding is the costly step: it takes a dozen tests on the word's
 * bits to find its class and cut out its fields. And a program spends
 * its time in loops, running the same words again. So the decoded
 * instruction, a value of Arm32_isa.t, is kept in a table by its
 * address:
 *
 *     slot = (pc / 4) mod 65536
 *     tags.(slot) = pc ?   yes: take code.(slot), with no decoding
 *                          no:  decode, and keep the result there
 *
 * It is a plain table and not a hash table. Two addresses 256 KB apart
 * share a slot and evict each other, which costs a decoding and nothing
 * else. A store does not empty a slot when the memory under it is
 * written. run32 empties the whole table when Memory.code_written is
 * set, by a debugger's write or by Plan 9's segflush; run64 never
 * does, so a program that rewrote its own code there would run the
 * old one (plan_arm.md, decision 5).
 * mini-qemu's loop is the same, with an MMU in the fetch, and it must
 * empty its cache when the kernel changes a mapping or says it wrote
 * code (Board).
 *
 * Between two instructions, and never inside one, the loop looks at
 * one flag, and a signal for the program is delivered there (Linux,
 * Plan9). It is the software's version of what a processor does with
 * its interrupt line, which it samples between instructions, and it is
 * the reason an instruction is atomic for a handler.
 *
 * modern:
 * Dynamic translation. Keeping the decoding is the first step of a
 * road whose end is QEMU. Instead of interpreting a decoded value
 * again each time, QEMU translates a block of guest instructions, up
 * to its branch, once to host machine code, keeps it by its address,
 * and jumps to it. Blocks that follow each other are chained, so the
 * loop above is not even returned to. Shade (Cmelik and Keppel, 1994)
 * and Embra (Witchel and Rosenblum, 1996) did it for simulators, and
 * Fabrice Bellard's QEMU (2003) made it portable and fast enough to
 * boot systems as a daily tool. The gain is several times an
 * interpreter's speed. The price is a code generator for each host,
 * and much care about code that changes. An interpreter in OCaml runs
 * wherever OCaml does, a browser included, and its speed is enough to
 * boot Plan 9 on mini-qemu.
 *
 * References: Fabrice Bellard, "QEMU, a Fast and Portable Dynamic
 * Translator" (USENIX Annual Technical Conference, FREENIX track,
 * 2005), six pages worth reading; Bob Cmelik and David Keppel, "Shade: A
 * Fast Instruction-Set Simulator for Execution Profiling"
 * (SIGMETRICS 1994). *)

type stats = { mutable instructions : int }

(* runs until the program exits (Linux.Exit). [trace], if given, is
 * called before each instruction. [signal] is called between two
 * instructions when Linux.signal_waiting is set; it sets st.next when
 * it enters a handler. *)
val run32 :
  trace:(int -> Arm32_isa.t -> unit) option -> Arm32_isa.state -> pc:int -> svc:(Arm32_isa.state -> int -> unit) ->
  signal:(Arm32_isa.state -> int -> unit) -> stats -> unit

(* after run32 raised Memory.Fault, the address of the instruction
 * that faulted *)
val fault_pc : int ref

(* the same for arm64 *)
val run64 :
  trace:(int -> Arm64_isa.t -> unit) option -> Arm64_isa.state -> pc:int -> svc:(Arm64_isa.state -> int -> unit) ->
  signal:(Arm64_isa.state -> int -> unit) -> stats -> unit
