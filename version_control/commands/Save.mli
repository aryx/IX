(* Save makes a commit from the work tree (git9's git/save: treeify,
 * mkcommit).
 *
 * Only the paths given change in HEAD's tree. The rest of the tree is
 * shared with HEAD's, subtree by subtree: a tree is rewritten only
 * along the paths, as in a persistent data structure. For each path:
 *
 *   gone from disk                          -> removed
 *   a file, tracked (not R in INDEX9)       -> its blob
 *   a file, untracked                       -> removed
 *   a directory where a tracked file was    -> removed
 *   a directory on the way to other paths   -> its tree, recursively;
 *                                              removed if left empty
 *
 * The commit's author and committer dates are the same date, in +0000,
 * as git9 writes them. The message is written as given. *)

type who = { name : string; email : string }

type commit = {
  author : who;
  committer : who;
  msg : string;
  date : int;
  parents : Hash.t list;
}

exception Error of string

(* the new commit's hash; [paths] are relative to the root, and
 * cleaned *)
val save : Repo.t -> commit -> string list -> Hash.t
