(* mini-singml: is a program's source safe? (decision 1 of
 * kernels/singularity's plan_system_singularity.md). A process of
 * mini-singularity is in the kernel's address space, kept from the
 * others' memory by its language only: its own code may be nothing
 * that makes an address or looks at a value as what it is not.
 * Refused:
 *   external                       a C function named, or a primitive
 *   M.x, open M                    M not one of the modules a program
 *                                  may name (below, and -allow's) nor
 *                                  one it defines: Obj, Marshal, Unix...
 *   unsafe_get, String.unsafe_blit a name that starts with unsafe_
 *   input_value                    a value read as any type
 *   [%...]                         an extension, which is code not seen here
 *
 * What is not looked at, and trusted: that mini-ml's type checker is
 * sound, and what the allowed modules do with their own externals (the
 * standard library, Sip). Singularity verified a program's compiled
 * code when it was installed; here the source is looked at when the
 * image is built, and the build is what is trusted.
 *
 * Why these and no others. A typed program can reach only what it
 * was given or made: OCaml has no operation that turns a number
 * into a reference. The ways out are the ones the language itself
 * marks: a C function (external), a primitive that skips a check
 * (unsafe_get past an array's end reads the next object), and the
 * few functions that lie about a type (Obj.magic, Marshal's and
 * input_value's result). With those gone, a process's reach is its
 * own heap and what the allowed modules do for it, and the list of
 * allowed modules is the whole of its privileges.
 *
 * terminology:
 * The trusted computing base: what must be right for the promise to
 * hold. For a process behind an MMU it is the processor and the
 * kernel's few thousand lines that write page tables. Here it is
 * this module, mini-ml's type checker and code generator, the
 * run-time system and the allowed libraries: more code, and code
 * that was not written to be a wall. That is the honest price of
 * the design, and Singularity's papers count theirs the same way.
 *
 * others:
 * Who checks, and what. Java's verifier (1995) checks the bytecode
 * at loading, so the compiler need not be trusted; Singularity
 * meant to check typed machine code the same way (typed assembly
 * language: Morrisett and others, 1998), and proof-carrying code
 * (George Necula, 1997) ships a proof with the binary. Linux's
 * eBPF verifier checks a small bytecode before it runs in the
 * kernel. Checking the source, as here, is the weakest of them: it
 * trusts everything after the parser.
 *
 * References: Hunt and Larus (2007), on what a SIP's safety rests
 * on. Morrisett, Walker, Crary and Glew, "From System F to Typed
 * Assembly Language" (POPL 1998). George Necula, "Proof-Carrying
 * Code" (POPL 1997). *)

(* the modules a program may name: of the standard library, those that
 * only compute; and mini-singularity's own *)
val allowed : string list

(* [check allowed tree]: what is refused, each its line and why, in the
 * source's order; [] for a safe program *)
val check : string list -> Ast.structure -> (int * string) list
