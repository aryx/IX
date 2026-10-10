(* The stack machine into Plan 9's assembly, for arm (5) or arm64 (7):
 * TinyC's and tiny-ml's back end, a record per machine (mini-cc's
 * decision 1). The text is what -S prints and what mini-asm's parser
 * reads into the object, so that mini-ml -S f.ml | mini-asm makes
 * mini-ml f.ml's object.
 *
 * The stack machine's stack is in registers (R1..R8 on arm, R1..R15 on
 * arm64): a push a move, an operation an instruction. At a call or an
 * allocation every register goes to its slot on the value stack, where
 * the collector sees it, and comes back after. The value stack's top
 * is a register 5c and 7c never allocate (R10, R26), stored in
 * ml_vsp before C is called. Every function is TEXT $-4 or $-8, a frame
 * mini-ld leaves alone: the prologue and epilogue are the compiler's,
 * so that a tail call is the epilogue then a B.
 *
 * try is setjmp's: BL ml_try(SB) records the stack pointers, the return
 * address and the previous handler in the frame, and returns 0; raise
 * restores them from the latest record and returns there again, with
 * the exception in R0. (A BL over the handler to a label, tiny-ml's
 * way, is not a call mini-ld links.)
 *
 * A value is a word, and its low bit says which kind (the runtime's
 * mlvalues.h, OCaml's representation):
 *
 *     an integer n      2n + 1                      3 is the word 7
 *     anything else     the address of a block:   +--------+---------
 *                       a pair, a closure, a      | header | field 0 ...
 *                       string, a float...        +--------+---------
 *                                                  size << 10 | tag
 *
 * So integers have 31 bits on arm and 63 on arm64, a constructor
 * without argument is an integer, and no type is needed to walk the
 * memory: a word that is odd is skipped, an even one is followed.
 * The arithmetic works on the tagged words: x + y is ADD then SUB $1
 * ((2x+1) + (2y+1) - 1), and [Ir.Int 1] is MOVW $3.
 *
 * Two stacks. The machine's (R13 on arm) has the return addresses and
 * C's frames, and never a value; the value stack (R10) has every ML
 * value that must outlive a call. A function's start, mini-ml -S of
 * let rec sum l = ... on arm:
 *
 *     TEXT f1_sum<>(SB), $-4
 *     SUB  $16, R13            the machine's frame; the link register
 *     MOVW R14, 0(R13)         saved in it
 *     ADD  $36, R10            nine slots on the value stack:
 *     MOVW R0, -36(R10)        slot 0, the closure
 *     MOVW R1, -32(R10)        slot 1, the argument l
 *     MOVW $0, R9              and the seven others zeroed: a slot is
 *     MOVW R9, -28(R10) ...    a value at all times, or 0
 *
 * A pair made, in place: ml_hp is moved up by three words and
 * compared with ml_limit; if there is room the header ($2048, two
 * fields of tag 0) and the fields are stored; if not, the registers
 * go to their slots, ml_vsp is set and ml_alloc, C, collects.
 *
 * The collector is the runtime's (gc.c), but its contract is this
 * module's: its roots are the value stack from its base to ml_vsp,
 * the units' globals (the table [startup] writes) and what C
 * registered. It copies what it reaches to the other half of the
 * heap (Cheney's algorithm) and changes the roots to the new
 * addresses: hence no value in a register across a call, and none on
 * the machine's stack, where it would be neither found nor updated.
 *
 * design:
 * A stack of one's own. A collector that moves blocks must know of
 * each word of each frame whether it is a value. A compiler usually
 * says so in tables, one entry a call site (the return address, the
 * frame's size, its live slots), and the collector walks the machine
 * stack by them: OCaml's frame tables. Here an object file cannot
 * hold an instruction's address as data (mini-ld gives addresses,
 * and there are no relocations), so the values go where no table is
 * needed. It costs a store and a load around each call, and it
 * buys what plan_ml.md's decision 5 lists: no assembly in the
 * runtime, C called as C, and a process of the kernel that is two
 * pointers. Fergus Henderson (2002) described the scheme, for
 * Mercury compiled to C; LLVM offers it under the name shadow stack.
 *
 * others:
 * A collector may also not know: Hans Boehm's (1988), for C, takes
 * every word of the stack that could be an address of the heap for
 * one. It then cannot move a block, since it cannot change a word
 * that may be an integer, and a copying collector is out.
 *
 * cs-history:
 * The garbage collector is John McCarthy's, for Lisp (1960): mark
 * what the roots reach, sweep the rest into a free list. Copying is
 * from the same decade (Marvin Minsky, 1963; Robert Fenichel and
 * Jerome Yochelson, 1969), and C. J. Cheney (1970) found how to do
 * it with no stack and no recursion: the copied blocks are the queue
 * of blocks still to scan, between two pointers of the new half. It
 * costs in proportion to what is alive, not to what died, which
 * suits a language that allocates as much as ML; and allocation is
 * the pointer moved above.
 *
 * modern:
 * OCaml's collector is generational: a small young heap collected
 * by copying, often, and what survives it promoted to an old heap,
 * marked and swept a slice at a time between the program's steps,
 * so that no pause is long. Most blocks die young and are never
 * copied. Here a collection copies everything alive, and the
 * program holds two heaps (gc.c has the numbers: mini-ld 267 MB
 * for a link where 54 are alive).
 *
 * others:
 * Exceptions. OCaml's native code keeps the handlers as records
 * linked through the machine's stack, the latest in a register:
 * try is two pushes, raise a few instructions, with no call; it is
 * why ML programs use exceptions for control (Not_found, Exit)
 * where a C++ programmer, whose throw walks tables frame by frame,
 * would not. ml_try is between the two: a call at each try.
 *
 * References: plan_ml.md, decisions 4 to 6; C. J. Cheney, "A
 * nonrecursive list compacting algorithm" (Communications of the
 * ACM 13(11), 1970), two pages; John McCarthy, "Recursive functions
 * of symbolic expressions and their computation by machine, part I"
 * (Communications of the ACM 3(4), 1960); Fergus Henderson,
 * "Accurate garbage collection in an uncooperative environment"
 * (ISMM 2002); Hans Boehm and Mark Weiser, "Garbage collection in an
 * uncooperative environment" (Software -- Practice and Experience
 * 18(9), 1988); Richard Jones, Antony Hosking and Eliot Moss, "The
 * Garbage Collection Handbook" (2011); Niklaus Wirth, "Compiler
 * Construction" (1996), for a stack machine's stack kept in
 * registers. *)

type mach

val arm : mach
val arm64 : mach
val arch : mach -> Asm.arch

(* the machine with gcc's calls of C (AAPCS): for -gas *)
val gnu : mach -> mach

(* a unit's assembly *)
val unit_ : mach -> Ir.unit_ -> string

(* the program's start, from the units in their order: ml_start (C
 * calls it with the value stack's base), ml_try, ml_raise, the table
 * of the units' globals, each unit's Init in a handler that prints an
 * uncaught exception *)
val startup : mach -> string list -> string

(* a block taken from the heap by the code itself, the runtime called
 * only when there is no room; and so a float's arithmetic, a new float
 * each (off: mini-ml -calls; never with gcc's C) *)
val alloc_in_place : bool ref
