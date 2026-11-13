(* Walk compares the work tree with the index and a commit. It is
 * git9's git/walk, which does the status and the index's upkeep in
 * one.
 *
 *   A new.c       added, and not in the commit
 *   M lib/a.c     its bytes or its x bit differ from the commit's
 *   R old.c       removed, or gone from disk, and in the commit
 *   U junk.o      untracked (shown with -fU)
 *   T README      tracked and the same (shown with -fT)
 *
 * Two sorted lists are merged. One is the index (INDEX9, or the
 * commit's own files with -b or when there is no INDEX9). The other is
 * the files on disk (only those under an indexed path, unless
 * untracked ones are asked for). A file whose fingerprint (Index9) is
 * the one recorded is taken as unchanged without being read. A file
 * that reads the same as the commit's gets its fingerprint recorded,
 * and INDEX9 is rewritten. The result's dirty kinds, in the order
 * R M A U, make git9's exit status: none means clean. *)

type change = Removed | Modified | Added | Untracked | Tracked

type opts = {
  show : change list;        (* -f; [] for R M A T *)
  quiet : bool;              (* -q *)
  bare : bool;               (* -c: paths without their letter *)
  base : Hash.t option;      (* -b: against this commit, without INDEX9 *)
  invalidate : bool;         (* -I: the index rebuilt from the commit *)
  rel : string option;       (* -r: paths shown relative to this dir *)
  paths : string list;       (* relative to the root, cleaned *)
}

val default : opts

exception Error of string

(* the lines to print, and the dirty kinds *)
val run : Repo.t -> opts -> string list * change list

val letter : change -> char

(* a path in a tree is a file's entry, or a directory's tree *)
type node = File of Object.entry | Dir of Hash.t

val lookup : Store.t -> Hash.t -> string -> node option
