(* git9's git/fs, the repository as a file system, without the file
 * system: its paths resolved on demand (decision 4 of plan_vcs.md).
 *
 *   ctl                       "branch heads/master\nrepo /home/me/src\n"
 *   HEAD/                     the commit HEAD names (empty if none)
 *   branch/heads/master/      a commit, from .git/refs/heads/master
 *   object/HASH               a blob's bytes, a tag's; a tree's or
 *                             commit's directory
 *   COMMIT/tree/...           its files
 *   COMMIT/parent             a hash a line
 *   COMMIT/msg                the message, leading blanks dropped
 *   COMMIT/hash, author       "HASH\n", "Name <email>\n"
 *   COMMIT/committer          readable, not listed, as in git9
 *
 * A symbolic link in a tree reads as its target's text (git9 follows
 * it inside the tree).
 *
 * plan9-is-cleaner:
 * git has a command, with its options, for each way of looking at
 * the past: show, cat-file, ls-tree, archive, a diff between two
 * commits. git9 has one file server, mounted in the repository at
 * .git/fs (fs.c's mntpt), where a commit is a directory, and the
 * programs one already knows do the rest: an old version is read
 * with cat, a tree listed with ls, two commits compared with
 * diff -r on their tree directories, and git9's own scripts are
 * written so. It is Plan 9's habit (a
 * window's text, the mail, the network are served the same way),
 * possible because mounting a server is anyone's (mini-mount). Here
 * there is no server: [resolve] answers for a path what git/fs
 * would, for the commands that the scripts wrote with those paths. *)

type node = File of string | Dir of string list

(* a path such as "HEAD/tree/lib/a.c"; None if nothing is there *)
val resolve : Repo.t -> string -> node option
