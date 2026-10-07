(* mini-singml: is a program's source safe? (decision 1 of
 * kernel/singularity's plan_system_singularity.md). A process of
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
 * image is built, and the build is what is trusted. *)

(* the modules a program may name: of the standard library, those that
 * only compute; and mini-singularity's own *)
val allowed : string list

(* [check allowed tree]: what is refused, each its line and why, in the
 * source's order; [] for a safe program *)
val check : string list -> Ast.structure -> (int * string) list
