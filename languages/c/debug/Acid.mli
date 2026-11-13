(* What -a writes: the program's types declared in acid's language
 * (acid.c), so that a debugger can print a value by its type. The text
 * is 5c's, byte for byte (debuggers/tests/acid/types/target.acid is the
 * output of 5c -an):
 *
 *     struct Node { char *name; Point p; Node *next; };
 *
 *     sizeofNode = 20;            the width
 *     aggr Node                   each member's format and offset ('A'
 *     {                           is a pointer to a complex type, and
 *         'X' 0 name;             is followed by the type's name)
 *         Point 4 p;
 *         'A' Node 12 next;
 *     };
 *     defn                        a function that prints a Node, given
 *     Node(addr) {                its address; acid's print calls it on
 *         complex Node addr;      a value of the type
 *         print("	name	", addr.name\X, "\n");
 *         ...
 *     };
 *     complex Node n1;            the type of a global, the type of a
 *     complex Node walk:n;        local (f:v); an enum's constants are
 *                                 written as variables
 *
 * The declarations are written as the compiler goes: a structure once
 * its body is aligned (Declare.sualign), and a name once it is declared
 * (Declare.dodecl, doenum). In acid's syntax a keyword cannot be a
 * name, so a member called loop is written $loop (amap).
 *
 * History: Phil Winterbottom's acid (1994) and 5c's -a came with Plan
 * 9's 2nd edition. The compiler, which knows the types, writes them in
 * the debugger's language, so the debugger knows no C (decision 6 of
 * plan_debugger.md; decision 14 puts the same text in the program,
 * with -g). *)

(* the level of -a: 0 for none, 1 for -a, and 2 for -aa (only the file
 * compiled, not its #includes) *)
val level : int ref

(* the declarations written, the last first. A structure's aggr and its
 * function are one declaration, and a variable's line is another
 * (mini-ld -g keeps each only once, because every file writes those of
 * libc.h) *)
val decls : string list ref

(* the declarations, as -a writes them *)
val text : unit -> string

(* writes the declarations of a structure or union, once the offsets of
 * its elements and its width are known (acidtype) *)
val acidtype : Tree.typ -> unit

(* writes the declaration of a name just declared (acidvar): the complex
 * type of a global or a local, or an enum's constant. fn is the type of
 * the function being defined (thisfn). *)
val acidvar : fn:Tree.typ option -> Tree.sym -> unit
