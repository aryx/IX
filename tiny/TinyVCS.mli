(* A tiny version control system, in one file. The full-size version
 * in ix, mini-git (version_control/), is a faithful copy of git9: it
 * uses git's formats, a staging file, packs, and a wire protocol. This
 * one keeps git's ideas -- objects named by the hash of their content,
 * trees of objects, a DAG of commits, three-way merge -- and for
 * everything else follows the roads taken by the systems that came
 * after git. Its commands are shown by example in the [help] string of
 * the .ml (which is what vcs -h prints):
 *
 * - {b The repository is one hash.} Objects are appended to a single
 *   file and never changed. The state of the repository (the branches,
 *   and which one is current) is an object too, an {e operation}, and
 *   .tvcs/head names the current operation. A command first writes its
 *   objects, then replaces head with one rename, so every command is
 *   atomic, just like the statements of TinyDatabase.ml.
 * - {b Every command can be undone.} Each operation points to the
 *   previous one, so the log of operations is the history of the
 *   repository itself (this is jj's operation log; git's reflogs, one
 *   per reference, are a partial version of it). Undo just sets head
 *   back.
 * - {b No staging area.} Every command starts by taking a snapshot of
 *   the work tree: all files are tracked, except dotfiles and what
 *   .tvcsignore lists (a name, or "*.ext"), and commit records that
 *   snapshot (as jj and Mercurial do, unlike git's index).
 * - {b A merge always succeeds.} When a file was changed on both sides
 *   and does not merge cleanly, it is committed as a {e conflict}: an
 *   entry holding the three versions plus the text with conflict
 *   markers. status shows it, and editing the file resolves it at the
 *   next commit (jj's first-class conflicts). The common ancestor is
 *   found by walking the DAG, not by comparing dates.
 * - Diff uses Myers' O(ND) algorithm, with unified output; merge is
 *   diff3, built on two diffs. Remotes are directories: clone, pull and
 *   push copy the objects that the other side is missing.
 *
 * So a repository is two files, plus what one of them names:
 *
 *     .tvcs/head       the hash of an operation, on one line;
 *                      replaced by a rename
 *     .tvcs/objects    a hash, a length, a newline, then that many
 *                      bytes, the object's text; then the next object;
 *                      the file is only ever appended to
 *
 *     head --> op (a merge) --prev--> op (a commit) --prev--> ...
 *               | current master       (after undo, head names this)
 *               | branch master ----> commit M --parent--> commit A ...
 *               | branch feature --.          '--parent--.
 *                                  '----> commit B <-----'
 *
 *     a commit --> tree
 *                   | f a.txt ----> blob
 *                   | x run.sh ---> blob
 *                   | d src ------> tree ...
 *                   | c b.txt ----> the text with conflict markers,
 *                                   and the three versions, each a blob
 *
 * There are four kinds of objects, each named by the SHA-1 of its
 * text: a blob (the bytes of a file); a tree (one line per entry: f
 * for a file, x for an executable file, d for a directory, c for a
 * conflict with its three versions); a commit (a tree, its parents, a
 * date, an author and a message); and an operation (the previous
 * operation, what was done, the current branch, and the commit of
 * every branch). A hash names its object and everything below it: two
 * commits with the same tree hash have the same files, a subtree that
 * did not change is stored only once, and the 40 hex digits in head
 * stand for the whole repository along with its history.
 *
 * The text of the objects uses a format specific to this file, which
 * is canonical and readable ("tree\nf HASH name\n..."); it is hashed
 * with SHA-1 (Sha1) and stored as it is. What is dropped: git's formats, compression (old: deflate,
 * lib_compression's Zlib; gone when tiny-vcs went to tiny-kernel, as
 * plan_tiny_self_hosting.md says), packs and deltas, the wire protocol,
 * the index, submodules and symbolic links, rename detection, tags,
 * and rebase.
 *
 * Exercises, all cheap because the repository is made of objects that
 * never change and are named by their hash, with its state being one
 * of those objects, an operation (redo needs no work at all: undo is
 * itself an operation, so undoing an undo is a redo):
 * - time travel: log @3 or switch @3 shows the repository as it was
 *   three operations ago; each operation still holds its branches, so
 *   this is just following prev three times;
 * - garbage collection: copy what is still reachable from the
 *   operations into a new file, and rename it over the old one (like
 *   the compaction of TinyDatabase); the rename is atomic, so a crash
 *   leaves the old file intact;
 * - two commands at once: since head is replaced by a rename, the last
 *   command wins and the operation of the other one is lost; instead,
 *   re-read head just before the rename, and if it moved, record an
 *   operation with both as parents and their branches merged (jj's
 *   concurrent operations, merged rather than prevented by a lock);
 * - detecting renames: a file that disappeared and a new file with the
 *   same hash are one file that moved; content addressing gives this
 *   for free;
 * - patience diff next to Myers': use the lines that appear exactly
 *   once on both sides as anchors, then run Myers between them (Bram
 *   Cohen, 2005); it often gives a more readable diff of code;
 * - a lazy clone: copy the operations and commits, and fetch a blob
 *   from the source only when it is read; its hash names it wherever
 *   it is.
 *
 * Where it stands: Sha1 is an ix library (lib_crypto), also used by
 * mini-git, which deflates its objects with Zlib (lib_compression;
 * Zlib.mli explains what a deflated object is). mini-git's Object,
 * Loose, Pack and Index9
 * implement git's own formats for what is, here, one text format and
 * one file. A file that is only appended to, plus one small write to
 * commit, is also how TinyDatabase works; and the stamps of
 * TinyBuildSystem are digests of contents for the same reason as here:
 * a name derived from the content can never be stale.
 *
 * cs-history:
 * Version control went from tracking one file, to one tree, to one
 * graph. SCCS (Marc Rochkind, Bell Labs, 1972) and RCS (Walter Tichy,
 * 1982) stored the versions of a single file as deltas, with a lock
 * saying who was editing it. CVS and Subversion (2000) versioned a
 * whole tree on a server, and merged where the earlier systems locked.
 * BitKeeper gave each developer a complete repository; Linux used it
 * from 2002 until its free licence was withdrawn in April 2005, and
 * within weeks Linus Torvalds had written git, and Matt Mackall
 * Mercurial. Naming everything by the hash of its content came from
 * Monotone (Graydon Hoare, 2003), which Torvalds thought was right in
 * its idea but too slow.
 *
 * terminology:
 * A commit here, as in git, is a snapshot: a whole tree. A diff is
 * computed on demand between two trees, and a merge between three.
 * Systems of the other family (Darcs, Pijul) store the changes
 * themselves, as patches, and a version is a set of applied patches;
 * they can tell that two histories contain the same changes in a
 * different order, which a graph of snapshots cannot. Storing deltas
 * to save space, as RCS and git's packs do, is a separate matter: it
 * is just a way to encode snapshots.
 *
 * plan9-is-cleaner:
 * A store where the address of a block is the hash of its bytes, and
 * blocks are written once and never changed, is Plan 9's Venti (Sean
 * Quinlan and Sean Dorward, 2002), which sits under the Fossil file
 * server. A snapshot of a whole file system is a single hash, taken
 * every night, and two snapshots that share files share their blocks.
 * git is the same idea applied to source code, with a commit where
 * Venti has a root.
 *
 * References:
 *  - E. W. Myers, "An O(ND) Difference Algorithm and Its Variations"
 *    (Algorithmica, 1986)
 *  - S. Khanna, K. Kunal and B. C. Pierce, "A Formal Investigation of
 *    Diff3" (FSTTCS, 2007)
 *  - M. von Zweigbergk, Jujutsu (jj, 2019-): the working copy as a
 *    commit, the operation log, and first-class conflicts
 *  - L. Torvalds, git (2005): the object model
 *  - R. C. Merkle, "A Digital Signature Based on a Conventional
 *    Encryption Function" (CRYPTO, 1987): the tree of hashes
 *  - B. Cohen, patience diff (2005)
 *)

(* a command and its arguments, done in the repository found from the
 * current directory: init, commit, log, diff, switch, merge, undo... *)
val run : < Cap.env; Cap.open_in; Cap.open_out; Cap.stdout; Cap.readdir > -> string list -> unit
