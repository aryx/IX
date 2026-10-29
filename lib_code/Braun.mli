(* SSA's construction, Braun et al.'s, whatever the instructions: the
 * part that finds each variable's value where it is read, and places
 * the phis. A compiler fills its blocks in order, and for each
 * instruction says what it writes (write) and asks what it reads
 * (read); the value of a variable not written in the block is asked
 * of its predecessors, a phi made where they are several. A block is
 * sealed once all its predecessors are filled (seal_ready): before,
 * a read makes a phi without operands, which it gets at the sealing.
 * mini-ml's and mini-cc's Ssa_build give it their own variables (a
 * slot of the frame, a C variable, a position of the stack at a
 * block's edge) and make the phis, the instructions; the values are
 * their numbers.
 *
 *     b1: x = ...            read x in b3: not in b3, b3 has two
 *     b2: x = ...            predecessors: phi [b1 x1] [b2 x2]
 *     b3: ... x ...
 *
 * trivial is the cleanup after: a phi whose operands are one value
 * (and itself), made where the variable was not changed, is that
 * value, and others may become so in turn.
 *
 * Reference: Matthias Braun, Sebastian Buchwald, Sebastian Hack,
 * Roland Leissa, Christoph Mallon and Andreas Zwinkau, "Simple and
 * Efficient Construction of Static Single Assignment Form" (Compiler
 * Construction 2013), its algorithms 1 to 3. *)

type 'var t

(* n blocks; their predecessors; a new phi of a variable in a block,
 * without operands yet (its value); its operands given, a value for
 * each predecessor; the value of a variable read where no definition
 * reaches (the entry: a zero, an undefined) *)
val create :
  preds:(int -> int list) ->
  new_phi:('var -> int -> int) ->
  set_operands:('var -> int -> (int * int) list -> unit) ->
  missing:('var -> int -> int) ->
  int -> 'var t

(* the variable's value now in the block *)
val write : 'var t -> 'var -> int -> int -> unit
val read : 'var t -> 'var -> int -> int

(* a block's predecessors are all known: its phis get their operands *)
val seal : 'var t -> int -> unit

(* a block filled, every instruction of it read *)
val fill : 'var t -> int -> unit

(* each block whose predecessors are all filled sealed; then, at the
 * end, the others *)
val seal_ready : 'var t -> unit
val seal_rest : 'var t -> unit

(* the trivial phis taken out of each block's (set_phis), until none is
 * left: a value's replacement then (itself if none); operands: a
 * phi's operands, None for a value that is not a phi *)
val trivial :
  phis:(int -> int list) ->
  set_phis:(int -> int list -> unit) ->
  operands:(int -> int list option) ->
  int -> (int -> int)
