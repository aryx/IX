(* tiny-ar: objects kept in one file, a library, for tiny-ld. Its
 * usage, by examples, is in [help] (what tiny-ar -h prints).
 *
 * An archive is its objects, each after its name and size on a line
 * (TinyLibMachine's to_archive), and tiny-ld links them all, in
 * their order: the library's units are a list a link names once
 * (TinyLibCore/stdlib.a, every ML program's), not its 24 objects.
 *
 * twin:
 * mini-ar (linker/tools/Ar.ml), Plan 9's ar (principia's
 * linkers/misc/ar.c).
 * 
 * dropped: its keys but t (r, d, x, its order's a
 * and b: an archive is made again whole, by a Buildfile, -o as the
 * other tools say); the header's date, owner and mode (a library made
 * twice has the same bytes, what tiny-build's stamps compare); the
 * index (Plan 9's __.SYMDEF, mini-ar's names beside each object), which
 * a linker that picks members by what they define reads first:
 * tiny-ld takes them all, its sweep leaving out what nothing
 * reaches. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* [main caps argv]: tiny-ar's command line, -o lib.a file.o... or -t
 * lib.a *)
val main : < caps; .. > -> string array -> Exit.t
