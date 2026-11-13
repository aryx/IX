(* Configuration lookups, in the "remote.origin.url" style, done as
 * git9's conf.c does them: line by line, without a real parser.
 *
 *   [remote "origin"]
 *   	url = git://example.org/repo
 *
 * [lookup caps files "remote \"origin\".url"] splits its key at the
 * first dot. It scans for a line starting with "[remote \"origin\"]"
 * at column 0 (an indented header is not seen), and then for a line
 * whose text starts with the key followed, after blanks, by "=". The
 * value is the rest of the line, trimmed. A section of several words
 * must be quoted as git writes it. *)

(* the values from the first file that has one: its first match, or,
 * with [all], every match in that file *)
val lookup : < Cap.open_in; .. > -> all:bool -> Fpath.t list -> string -> string list

(* the files git9 reads: the repository's config, $HOME/lib/git/config
 * and /lib/git/config *)
val default_files : Fpath.t -> Fpath.t list
