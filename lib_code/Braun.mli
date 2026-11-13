(* Braun et al.'s construction of SSA form, for any kind of
 * instructions. This is the part that finds each variable's value
 * where it is read, and places the phis. A compiler fills its blocks
 * in order. For each instruction, it says what the instruction writes
 * (write) and asks what it reads (read). The value of a variable that
 * is not written in the block is asked of the block's predecessors,
 * and a phi is made where there are several of them. A block is sealed
 * once all its predecessors are filled (seal_ready). Before that, a
 * read makes a phi without operands, which gets them at the sealing.
 * mini-ml's and mini-cc's Ssa_build give it their own variables (a
 * slot of the frame, a C variable, a position of the stack at a
 * block's edge), and they make the phis and the instructions; the
 * values are the numbers of those instructions.
 *
 *     b1: x = ...            reading x in b3: x is not written in b3,
 *     b2: x = ...            and b3 has two predecessors, so x is
 *     b3: ... x ...          phi [b1 x1] [b2 x2]
 *
 * trivial is the cleanup afterwards. A phi whose operands are all one
 * value (or itself), made where the variable was not changed, is that
 * value, and other phis may become trivial in turn.
 *
 * Reference: Matthias Braun, Sebastian Buchwald, Sebastian Hack,
 * Roland Leissa, Christoph Mallon and Andreas Zwinkau, "Simple and
 * Efficient Construction of Static Single Assignment Form" (Compiler
 * Construction 2013), its algorithms 1 to 3. *)

type 'var t

(* [create ~preds ~new_phi ~set_operands ~missing n] is for n blocks:
 * - [preds] gives a block's predecessors;
 * - [new_phi] makes a new phi of a variable in a block, without
 *   operands yet, and returns its value;
 * - [set_operands] gives a phi its operands, a value for each
 *   predecessor;
 * - [missing] gives the value of a variable read where no definition
 *   reaches (at the entry: a zero, or an undefined value). *)
val create :
  preds:(int -> int list) ->
  new_phi:('var -> int -> int) ->
  set_operands:('var -> int -> (int * int) list -> unit) ->
  missing:('var -> int -> int) ->
  int -> 'var t

(* [write] sets the variable's value now in the block, and [read] asks
 * for it *)
val write : 'var t -> 'var -> int -> int -> unit
val read : 'var t -> 'var -> int -> int

(* [seal] says that a block's predecessors are all known, and its phis
 * get their operands *)
val seal : 'var t -> int -> unit

(* [fill] says that a block is filled: every instruction of it has been
 * read *)
val fill : 'var t -> int -> unit

(* [seal_ready] seals each block whose predecessors are all filled;
 * then, at the end, [seal_rest] seals the others *)
val seal_ready : 'var t -> unit
val seal_rest : 'var t -> unit

(* [trivial ~phis ~set_phis ~operands n] takes the trivial phis out of
 * each block's phis (with set_phis), until none is left. It returns
 * each value's replacement (the value itself if it has none).
 * [operands] gives a phi's operands, or None for a value that is not a
 * phi. *)
val trivial :
  phis:(int -> int list) ->
  set_phis:(int -> int list -> unit) ->
  operands:(int -> int list option) ->
  int -> (int -> int)
