(* Log shows the history, as git9's log.c does.
 *
 *   Hash:	1f7a7a472abf3dd9643fd615f6da379c4acb3e3a
 *   Author:	Ori <ori@eigenstate.org>
 *   Date:	Sun Sep 13 12:26:40 GMT 2020
 *
 *   	the message, each line after a tab
 *
 * (Committer: follows Author: when they differ.) With -s, a commit is
 * one line, "HASH first line". The date is the author's, shifted by
 * its zone as git9 shifts it, and printed in Plan 9's ctime format in
 * GMT (git9 prints the machine's zone: deliberate difference 4).
 *
 * With paths, a commit is shown when what the paths name differs from
 * what they name in any parent (a root commit is shown when it has
 * them). The paths make a filter tree of path elements, compared by
 * hash, and a subtree is read only when it differs. *)

type filter

(* the paths are relative to the root, and cleaned. "." never matches:
 * git9's cleanname makes the root ".", and no tree entry has that name *)
val filter : string list -> filter
val matches : Store.t -> filter option -> Object.commit -> bool

val show : short:bool -> Hash.t -> Object.commit -> string

(* Plan 9's ctime, in GMT: "Sun Sep 13 12:26:40 GMT 2020\n" *)
val ctime : int -> string
