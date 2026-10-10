(* The loop: fetch, decode (once: a direct-mapped cache of decoded
 * instructions by address, plan_arm.md decision 5), execute.
 *
 * A processor is this loop in silicon, and an interpreter is the
 * loop written down:
 *
 *     forever:
 *       word  = memory[pc]            fetch
 *       instr = decode word           which instruction, which fields
 *       execute instr                 registers, flags, memory; and
 *       pc    = the next one          pc + 4, or where a branch says
 *
 * Decoding is the costly step, a dozen tests on the word's bits to
 * find its class and cut its fields, and a program spends its time
 * in loops, on the same words. So the decoded instruction, a value
 * of Arm32_isa.t, is kept in a table by its address:
 *
 *     slot = (pc / 4) mod 65536
 *     tags.(slot) = pc ?   yes: code.(slot), no decoding
 *                          no:  decode, and keep it there
 *
 * A table and not a hash table: two addresses 256 KB apart share a
 * slot and evict each other, which costs a decoding and nothing
 * else. Nothing empties a slot when the memory under it is written:
 * a program that rewrote its own code would run the old one. The
 * programs run here do not (plan_arm.md, decision 5); mini-qemu's
 * loop, the same with an MMU in the fetch, must empty its cache when
 * the kernel changes a mapping or says it wrote code (Board).
 *
 * Between two instructions and never inside one, the loop looks at
 * one flag: a signal for the program is delivered there (Linux,
 * Plan9). It is the software's version of what a processor does
 * with its interrupt line, sampled between instructions, and the
 * reason an instruction is atomic for a handler.
 *
 * modern:
 * Dynamic translation. Keeping the decoding is the first step of a
 * road whose end is QEMU: instead of a decoded value interpreted
 * again each time, a block of guest instructions, up to its branch,
 * is translated once to host machine code, kept by its address,
 * and jumped to; blocks that follow each other are chained so that
 * the loop above is not even returned to. Shade (Cmelik and Keppel,
 * 1994) and Embra (Witchel and Rosenblum, 1996) did it for
 * simulators, Fabrice Bellard's QEMU (2005) made it portable and
 * fast enough to boot systems as a daily tool. The gain is several
 * times an interpreter's speed; the price is a code generator for
 * each host, and all the care about code that changes. An
 * interpreter in OCaml runs wherever OCaml does, a browser
 * included, and its speed is enough to boot Plan 9 on mini-qemu.
 *
 * References: Fabrice Bellard, "QEMU, a Fast and Portable Dynamic
 * Translator" (USENIX Annual Technical Conference, FREENIX track,
 * 2005), six pages, to read; Bob Cmelik and David Keppel, "Shade: A
 * Fast Instruction-Set Simulator for Execution Profiling"
 * (SIGMETRICS 1994). *)

type stats = { mutable instructions : int }

(* runs until the program exits (Linux.Exit), with [trace], if some,
 * called before each instruction, and [signal] between two when Linux.signal_waiting
 * is set (it sets st.next when it enters a handler) *)
val run32 :
  trace:(int -> Arm32_isa.t -> unit) option -> Arm32_isa.state -> pc:int -> svc:(Arm32_isa.state -> int -> unit) ->
  signal:(Arm32_isa.state -> int -> unit) -> stats -> unit

(* the same for arm64 *)
val run64 :
  trace:(int -> Arm64_isa.t -> unit) option -> Arm64_isa.state -> pc:int -> svc:(Arm64_isa.state -> int -> unit) ->
  signal:(Arm64_isa.state -> int -> unit) -> stats -> unit
