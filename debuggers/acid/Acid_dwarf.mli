(* A program's DWARF types, turned into acid's declarations
 * (plan_debugger.md, stage 8a). They are what 5c -a writes for a C
 * file, made here from what gcc wrote in .debug_info (Dwarf_info), for
 * a program built by gcc that has no .acid. mini-acid runs them as the
 * program's declarations, and print then shows a structure by its
 * members (port.acid's pcomplex):
 *
 *     structure_type "Node" (or a typedef's of an unnamed one)
 *       member "name" char*, at 0       'Y' 0 name;
 *       member "p" Point, at 8          Point 8 p;
 *       member "next" Node*, at 16      'A' Node 16 next;
 *     variable "n1" Node, DW_OP_addr    complex Node n1;
 *     subprogram "walk"
 *       formal_parameter "n" Node*       complex Node walk:n;
 *
 * The members' formats are 5c's letters, chosen by the encoding and
 * the size of their base types (C, b, d, u, D, U, V, W, f, F; Y for a
 * pointer of 8 bytes, a for an array). Frame64 finds a local's address
 * (its location is relative to the frame's base). Two things are not
 * written: 5c's printing functions (port.acid's pcomplex prints by the
 * aggr instead), and the bits of a bit field. *)

(* the declarations of the compilation units' structures and globals *)
val decls : Dwarf_info.die list -> string
