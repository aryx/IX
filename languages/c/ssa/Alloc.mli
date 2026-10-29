(* Where each SSA value of a C function lives (plan_cc_ssa.md, step 2):
 * a register, a slot of the frame, a parameter's own slot, or nowhere.
 * mini-ml's Alloc for C, its Alloc.mli the long story.
 *
 * Liveness first, a backward dataflow over the blocks to its fixpoint,
 * a phi's operand live at its predecessor's end and its definition at
 * its block's start. Plan 9 saves no register at a call, the caller
 * does: a value live across calls is in memory when they cost more
 * than its uses gain (a load after each, against a load a use, by
 * their loops), else in a register stored once where it is made and
 * loaded after each call. The values
 * are chosen, the most used first (a use in a loop 8 times one outside
 * it), each while no point has more of them live than there are
 * registers, then colored in the dominator tree's order, the lowest
 * register no value live after the definition holds: for SSA, whose
 * interference is chordal, that order needs no more colors than the
 * most values live at once (Hack, Grund and Goos). Integers and floats
 * each their own registers.
 *
 * What is not in a register is in a slot, the slots colored the same
 * way with no bound, so that two values whose lives do not meet share
 * one; a parameter not in a register stays in its own (Home), which
 * nothing else writes. A constant or an address lives nowhere (Nil):
 * Ssa_gen makes it where it is read; so does a value nobody reads, an
 * instruction run for its effect.
 *
 * What is not done: a value in memory is loaded at each use, not once
 * between two calls; a phi's moves are not coalesced, its operands
 * getting its register only by the walk's order. *)

type loc = Reg of int | Slot of int | Home of Ssa.mem | Nil

(* nregs integer registers and nfregs floating-point ones, each
 * numbered from 0: each value's place; at a call, the values in a
 * register live across it and where each is saved (to load it after);
 * the slot a value in a register is stored to where it is made, if it
 * is live across calls; the slots of the frame *)
val alloc :
  Ssa.func -> nregs:int -> nfregs:int ->
  (Ssa.value -> loc) * (Ssa.value -> (Ssa.value * loc) list)
  * (Ssa.value -> int option) * int

(* the values live at each block's start and at its end *)
val liveness : Ssa.func -> int Set_.t array * int Set_.t array
