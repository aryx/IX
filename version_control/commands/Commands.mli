(* git9's commands are its rc scripts (init.rc, add.rc, commit.rc,
 * branch.rc, ...). Here they are OCaml functions that follow the
 * scripts line for line: what they print, their messages and their
 * order. What the scripts did through git/fs's mount (cp from
 * .git/fs/object/H/tree/f, test -e $gitfs/HEAD/tree) is done on the
 * store directly. What they did through git/walk, git/save and
 * git/query calls Walk, Save and Query.
 *
 * A command returns its exit status. A script's "die msg" raises Die,
 * which CLI prints as "git/CMD: msg" before it exits with 1. *)

type caps = < Store.caps; Cap.stdout; Cap.stderr; Cap.fork; Cap.exec; Cap.wait; Cap.pipe >

exception Die of string

val init : caps -> string list -> int
val add : caps -> string list -> int
val rm : caps -> string list -> int
val commit : caps -> string list -> int
val branch : caps -> string list -> int
val revert : caps -> string list -> int
val diff : caps -> string list -> int
val merge : caps -> string list -> int
val repack : caps -> string list -> int
val get : caps -> string list -> int
val send : caps -> string list -> int
val serve : caps -> string list -> int
val clone : caps -> string list -> int
val pull : caps -> string list -> int
val push : caps -> string list -> int

(* indexes and saves a pack's bytes, and returns its name *)
val save_pack : Repo.t -> string -> string
val walk : caps -> string list -> int
val save : caps -> string list -> int

(* the message cleaned as commit.rc's cleanmsg does it: the # lines are
 * dropped, a run of blank lines becomes one, the leading and trailing
 * blank lines and the trailing blanks are dropped, and each line ends
 * with a newline *)
val cleanmsg : string -> string
