(* A program's DWARF types as acid's declarations (plan_debugger.md,
 * stage 8a): what 5c -a writes of a C file, made from what gcc wrote
 * in .debug_info (Dwarf_info), for a program of gcc's that has no
 * .acid; mini-acid runs it as the program's declarations, and print
 * shows a structure by its members (port.acid's pcomplex):
 *
 *     structure_type "Node" (or a typedef's of an unnamed one)
 *       member "name" char*, at 0       'Y' 0 name;
 *       member "p" Point, at 8          Point 8 p;
 *       member "next" Node*, at 16      'A' Node 16 next;
 *     variable "n1" Node, DW_OP_addr    complex Node n1;
 *     subprogram "walk"
 *       formal_parameter "n" Node*       complex Node walk:n;
 *
 * the members' formats 5c's letters by their base types' encodings and
 * sizes (C, b, d, u, D, U, V, W, f, F; Y a pointer of 8 bytes, a an
 * array); a local's address is Frame64's (its location on the
 * frame's base). Not said: 5c's printing functions (port.acid's
 * pcomplex prints by the aggr), a bit field's bits. *)

(* the declarations of the compilation units' structures and globals *)
val decls : Dwarf_info.die list -> string
