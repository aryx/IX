(* What -a writes: acid's declarations of the program's types (acid.c),
 * for a debugger to print a value by its type. 5c's text, byte for
 * byte (debuggers/tests/acid/types/target.acid is 5c -an's):
 *
 *     struct Node { char *name; Point p; Node *next; };
 *
 *     sizeofNode = 20;            the width
 *     aggr Node                   each member's format and offset ('A':
 *     {                           a pointer to a complex type, its name)
 *         'X' 0 name;
 *         Point 4 p;
 *         'A' Node 12 next;
 *     };
 *     defn                        a function printing one, given its
 *     Node(addr) {                address: acid's print calls it on a
 *         complex Node addr;      value of the type
 *         print("	name	", addr.name\X, "\n");
 *         ...
 *     };
 *     complex Node n1;            a global's type, a local's (f:v), an
 *     complex Node walk:n;        enum's constants as variables
 *
 * written as the compiler goes: a structure once its body is aligned
 * (Declare.sualign), a name once declared (Declare.dodecl, doenum).
 * In acid's syntax a keyword is no name: a member called loop is
 * $loop (amap).
 *
 * History: Phil Winterbottom's acid (1994) and 5c's -a, Plan 9 2nd
 * edition: the compiler, which knows the types, writes them in the
 * debugger's language; the debugger knows no C (decision 6 of
 * plan_debugger.md; decision 14: the same text in the program, -g). *)

(* -a's level: 0 none, 1 -a, 2 -aa (only the file compiled, not its
 * #includes) *)
val level : int ref

(* the declarations written, the last first: a structure's aggr and
 * function one, a variable's line another (mini-ld -g keeps each once:
 * every file says libc.h's) *)
val decls : string list ref

(* them as -a writes them *)
val text : unit -> string

(* a structure or union, its elements' offsets and width known
 * (acidtype) *)
val acidtype : Tree.typ -> unit

(* a name declared (acidvar): a global's or a local's complex type, an
 * enum's constant; fn the function being defined (its type: thisfn) *)
val acidvar : fn:Tree.typ option -> Tree.sym -> unit
