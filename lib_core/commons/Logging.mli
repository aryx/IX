(* The programs' traces, by the Logs library, on stderr: none but the
 * warnings by default, more with IX_LOG=info or IX_LOG=debug (an
 * environment variable, which needs no flag of the program's), or by
 * the flags every ix program may take, [flags]: -v, -debug, -quiet
 * (docs/man/1/common.md, the author: "those -v -debug -quiet should be
 * part of every ix programs"). What the programs print as their
 * originals do is not logging and does not go through here. *)
(* [name]: the program's, heading each line *)
val setup : < Cap.env; Cap.stderr; .. > -> name:string -> unit

(* -v (info), -debug, -quiet (not even the warnings): a program's
 * Arg options, the level set as the flag is read *)
val flags : (string * Arg.spec * string) list
