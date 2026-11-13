(* tiny-ar: keeps several objects in one file, a library, for tiny-ld.
 * Its usage, by examples, is in [help] in TinyArchiver.ml (what tiny-ar
 * -h prints).
 *
 * An archive is its objects, each one preceded by a line with its name
 * and its size (TinyLibMachine's to_archive). tiny-ld links all of
 * them, in their order. So a link names a library's units once, as one
 * file (TinyLibCore/stdlib.a, used by every ML program), instead of
 * its 24 objects.
 *
 * twin:
 * The twin is mini-ar (linker/tools/Ar.ml), which is Plan 9's ar
 * (principia's linkers/misc/ar.c).
 *
 * dropped:
 * - All of ar's keys except t: there is no r, d or x, nor a and b for
 *   the order.
 *   An archive is always made again whole, by a Buildfile, with -o as
 *   in the other tools.
 * - The date, owner and mode in the header. This way a library made
 *   twice has the same bytes, which is what tiny-build's stamps
 *   compare.
 * - The index (Plan 9's __.SYMDEF, mini-ar's names next to each
 *   object). A linker that picks members by what they define reads the
 *   index first; tiny-ld takes all the members, and its sweep leaves
 *   out what nothing reaches. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* The arguments are -o lib.a file.o..., or -t lib.a. *)
val main : < caps; .. > -> string array -> Exit.t
