(* Finding the programs a unit is part of, from the unit: Module_finder's
 * question asked the other way. Module_finder starts at a program's main
 * file and finds the units it names; this starts at a unit, a library's
 * (tiny/TinyLibGUI.ml) or a part of one program's (tiny/TinyOffice/
 * TinyTable.ml), and finds the main files that reach it, so that
 * mini-analyze -dead can say what is dead in it over all of them.
 *
 * The search is in the unit's part of the project (Module_finder.part_dir:
 * tiny/, its user/ and its tool directories with it), among the .ml
 * files, leaving out the directories whose name starts with . or _
 * (.git, _build...) and the tests' (tests/, a *_tests/): a function only
 * the tests call is not a program's, and [@@for_testing] says so where
 * it is meant. (Unless the unit is in a tests' directory itself, as
 * analyzers/tests/'s cases are: then they are searched too.) A file names a unit by a capitalized name before a dot
 * (TinyLibGUI.run, Module_finder's reading), or after open, include or a
 * module alias's = (module G = TinyLibGUI, ix's way, which the dot alone
 * would miss). Not any word of its name: a unit named Model or Screen
 * (TinyOffice's, TinyBrowser's) would then be named by every comment and
 * constructor of the word. A comment's TinyLibGUI.run still counts,
 * which costs one program read for nothing (it does not have the unit's
 * file, and the merge leaves it out). From the unit, the files that name
 * it, then the files that name theirs, up to the files nothing names:
 * the programs' main files (tiny/user/office.ml).
 *
 * A unit of several files is a platform's choice, which the flags make
 * (Module_finder.mli): TinyLibSystem's unix/, tinykernel/ and sdl/, of
 * which the window's sdl/ names TinyMachinePeer, and which every program
 * names. Only the file in a directory given (-own, -I) is followed, if
 * one is; else each. A name of unrelated directories (tiny-ml's and
 * tiny-cc's Lexer) is no platform's and none is given: each is followed,
 * and a program of the other one is read too, which the merge leaves
 * out, as above. *)

(* [programs caps dirs file]: the main files of the programs that reach
 * the unit of [file], sorted, the directories [dirs] (-own's, -I's)
 * deciding a platform; [] when nothing names it, a program's own main
 * file (or no project) *)
val programs : < Cap.open_in; Cap.readdir; .. > -> string list -> string -> string list
