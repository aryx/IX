(* git9's git/fs serves the repository as a file system. Here there is
 * no file system: its paths are resolved on demand (decision 4 of
 * plan_vcs.md).
 *
 *   ctl                       "branch heads/master\nrepo /home/me/src\n"
 *   HEAD/                     the commit HEAD names (empty if none)
 *   branch/heads/master/      a commit, from .git/refs/heads/master
 *   object/HASH               a blob's or a tag's bytes; a tree's or
 *                             a commit's directory
 *   COMMIT/tree/...           the commit's files
 *   COMMIT/parent             one hash on each line
 *   COMMIT/msg                the message, its leading blanks dropped
 *   COMMIT/hash, author       "HASH\n", "Name <email>\n"
 *   COMMIT/committer          can be read but is not listed, as in git9
 *
 * A symbolic link in a tree reads as the text of its target (git9
 * follows it inside the tree).
 *
 * plan9-is-cleaner:
 * git has a command, with its options, for each way of looking at
 * the past: show, cat-file, ls-tree, archive, a diff between two
 * commits. git9 has one file server, mounted in the repository at
 * .git/fs (fs.c's mntpt), where a commit is a directory, and the
 * programs you already know do the rest. An old version is read with
 * cat, a tree is listed with ls, two commits are compared with
 * diff -r on their tree directories, and git9's own scripts are
 * written that way. It is Plan 9's habit (a window's text, the mail
 * and the network are served the same way), and it is possible
 * because anyone can mount a server (mini-mount). Here there is no
 * server: for a path, [resolve] answers what git/fs would, for the
 * commands that the scripts wrote with those paths. *)

type node = File of string | Dir of string list

(* a path such as "HEAD/tree/lib/a.c"; None if nothing is there *)
val resolve : Repo.t -> string -> node option
