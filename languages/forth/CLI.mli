(* mini-forth: Forth (Forth.mli) on a terminal: files interpreted,
 * texts given, a prompt. Its usage: [help] in CLI.ml, what
 * mini-forth -h prints.
 *
 *     a text (a file, -e, a line typed)
 *        | Forth.interpret     the outer interpreter: a word at a time,
 *        |                     run, or compiled into the dictionary
 *        |-- Forth_prelude     IF, DO, VARIABLE...: Forth, read first
 *        '-- NEXT              the inner interpreter: the thread run
 *
 * There is no more: no tree, no pass. The files and the -e texts are
 * interpreted in order in one dictionary; a prompt says ok after a
 * line, as every Forth has since the teletype; -trace shows NEXT at
 * work. It is one of the machines ix has a language for, with
 * Pascal's P-machine, Prolog's WAM and Smalltalk's bytecode, and the
 * smallest of them. *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
