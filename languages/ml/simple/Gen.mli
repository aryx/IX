(* This module translates the stack machine into Plan 9's assembly,
 * for arm (5) or arm64 (7). It is TinyC's and tiny-ml's back end, with
 * a record for each machine (mini-cc's decision 1). The text is what
 * -S prints and what mini-asm's parser reads into the object, so that
 * mini-ml -S f.ml | mini-asm makes the same object as mini-ml f.ml.
 *
 * The stack machine's stack is in registers (R1..R8 on arm, R1..R15 on
 * arm64): a push is a move, and an operation is an instruction. At a
 * call or an allocation, every register goes to its slot on the value
 * stack, where the collector sees it, and comes back after. The value
 * stack's top is in a register that 5c and 7c never allocate (R10,
 * R26), and it is stored in ml_vsp before C is called. Every function
 * is TEXT $-4 or $-8, a frame that mini-ld leaves alone: the prologue
 * and epilogue are the compiler's, so that a tail call is the epilogue
 * followed by a B.
 *
 * try works as setjmp does: BL ml_try(SB) records the stack pointers,
 * the return address and the previous handler in the frame, and
 * returns 0; raise restores them from the latest record and returns
 * there again, with the exception in R0. (A BL over the handler to a
 * label, which is tiny-ml's way, is not a call that mini-ld links.)
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
 * without arguments is an integer, and no type is needed to walk the
 * memory: a word that is odd is skipped, and an even one is followed.
 * The arithmetic works on the tagged words: x + y is ADD then SUB $1
 * ((2x+1) + (2y+1) - 1), and [Ir.Int 1] is MOVW $3.
 *
 * Two stacks. The machine's (R13 on arm) has the return addresses and
 * C's frames, and never a value; the value stack (R10) has every ML
 * value that must outlive a call. Here is a function's start, as
 * mini-ml -S prints it for let rec sum l = ... on arm:
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
 * To make a pair, the registers go to their slots, ml_vsp is set, and
 * ml_alloc (in C) returns the block, after a collection when the heap
 * is full; then the fields are stored from their slots. Every
 * primitive of the runtime is a call here (a string's byte, a float's
 * sum, an int32's operation). ssa's Emit writes them as instructions
 * where they are used (open coding: see its section on them), and it
 * also takes the block from the heap in place, by moving ml_hp up and
 * comparing it with ml_limit. This module stays the simple path, the
 * one of -O0, and ssa's is the -O3 one, which compiles the start
 * object's functions too (the compile argument of startup).
 *
 * The collector is the runtime's (gc.c), but its contract is this
 * module's. Its roots are the value stack from its base to ml_vsp,
 * the units' globals (the table that [startup] writes) and what C
 * registered. It copies what it reaches to the other half of the
 * heap (Cheney's algorithm) and changes the roots to the new
 * addresses. Hence no value stays in a register across a call, and
 * none is on the machine's stack, where it would be neither found nor
 * updated.
 *
 * design:
 * A stack of one's own. A collector that moves blocks must know, for
 * each word of each frame, whether it is a value. A compiler usually
 * says so in tables, with one entry for each call site (the return
 * address, the frame's size, its live slots), and the collector walks
 * the machine stack with them: these are OCaml's frame tables. Here an
 * object file cannot
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
 * copied. The collector here is generational too, since 2026-10-23
 * (gc.c): a young generation is collected by copying, and its
 * survivors are promoted to the halves, which a major collection
 * copies whole, still with Cheney's algorithm. So the program holds
 * two heaps (gc.c has the numbers: mini-ld uses 267 MB for a link
 * where 54 MB are alive). Generations need a write barrier: a block
 * stored in an old one is remembered (ml_modify, from SetField and
 * SetIndex), since the young collection does not scan the old.
 * (David Ungar, "Generation scavenging", 1984: the idea, for
 * Smalltalk; Henry Lieberman and Carl Hewitt, 1983, before.)
 *
 * others:
 * Exceptions. OCaml's native code keeps the handlers as records
 * linked through the machine's stack, with the latest in a register:
 * try is two pushes, and raise is a few instructions, with no call.
 * This is why ML programs use exceptions for control (Not_found,
 * Exit) where a C++ programmer, whose throw walks tables frame by
 * frame, would not. ml_try is between the two: it costs a call at
 * each try.
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

(* the machine, calling C as gcc does (AAPCS): for -gas *)
val gnu : mach -> mach

(* the instructions of a raise, with the exception in R0 (Emit uses
 * them too) *)
val raise_ : Asm.arch -> string list

(* the raise, in a handler, of an exception that matched none of its
 * cases: ml_reraise, which keeps the trace as the first raise left
 * it *)
val reraise_ : string list

(* a unit's assembly *)
val unit_ : mach -> Ir.unit_ -> string

(* the program's start, from the units in their order: ml_start (which
 * C calls with the value stack's base), ml_try, ml_raise, the table of
 * the units' globals, and each unit's Init, called in a handler that
 * prints an uncaught exception. That handler's function and the curry
 * functions are compiled by the function given (unit_'s, or ssa's
 * Emit). *)
val startup : mach -> (Ir.func list -> string) -> string list -> string

