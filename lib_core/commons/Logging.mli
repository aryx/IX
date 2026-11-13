(* The programs write their traces on stderr with the Logs library. By
 * default only the warnings are shown. You get more with IX_LOG=info or
 * IX_LOG=debug, an environment variable, so the program needs no flag
 * for it. You also get more with [flags], the flags that every ix
 * program may take: -v, -debug and -quiet (see docs/man/1/common.md;
 * the author: "those -v -debug -quiet should be part of every ix
 * programs"). What a program prints because its original prints it is
 * not logging, and it does not go through here. *)
(* [name] is the program's name, which starts each line *)
val setup : < Cap.env; Cap.stderr; .. > -> name:string -> unit

(* The Arg options of a program: -v (info), -debug, and -quiet (not even
 * the warnings). Each sets the level as soon as the flag is read. *)
val flags : (string * Arg.spec * string) list
