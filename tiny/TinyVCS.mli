(* A tiny version control system, in one file. mini-git (version_control/)
 * is git9, faithfully: git's formats, a staging file, packs, a wire
 * protocol. This keeps git's ideas -- objects named by the hash of
 * their content, trees of them, a DAG of commits, three-way merge --
 * and takes, for the rest, the roads the systems after git took (its
 * commands, by example: [help] below, what tiny-vcs -h prints):
 *
 * - {b The repository is one hash.} Objects are appended to one file,
 *   never changed; the state -- the branches, the current one -- is an
 *   object too, an {e operation}, and .tvcs/head names the current
 *   one. A command writes its objects, then replaces head, one rename:
 *   every command is atomic, as TinyDatabase.ml's statements are.
 * - {b Every command can be undone.} Each operation points to the one
 *   before, so the log of operations is the history of the repository
 *   itself (jj's operation log; git's reflogs, per reference, are the
 *   partial version): undo sets head back.
 * - {b No staging area.} Every command first snapshots the work tree:
 *   all files are tracked but dotfiles and what .tvcsignore names (a
 *   name, or "*.ext"); commit takes the snapshot (jj and Mercurial,
 *   against git's index).
 * - {b A merge always succeeds.} A file both sides changed and that
 *   does not merge is committed as a {e conflict}, an entry holding the
 *   three versions and the text with markers; status shows it, and
 *   editing the file resolves it, at the next commit (jj's first-class
 *   conflicts). The common ancestor is found on the DAG, not by dates.
 * - Diff is Myers' O(ND) algorithm, unified output; merge is diff3
 *   over two of them. Remotes are directories: clone, pull and push
 *   copy the objects the other side lacks.
 *
 * A repository, then, is two files and what one of them names:
 *
 *     .tvcs/head       an operation's hash, a line: replaced by rename
 *     .tvcs/objects    a hash, a length, a newline, that many deflated
 *                      bytes; again for the next object: only appended
 *
 *     head --> op (a merge) --prev--> op (a commit) --prev--> ...
 *               | current master       (undo: head names this one)
 *               | branch master ----> commit M --parent--> commit A ...
 *               | branch feature --.          '--parent--.
 *                                  '----> commit B <-----'
 *
 *     a commit --> tree
 *                   | f a.txt ----> blob
 *                   | x run.sh ---> blob
 *                   | d src ------> tree ...
 *                   | c b.txt ----> the text with its markers, and
 *                                   the three versions, a blob each
 *
 * Four kinds of object, each named by the SHA-1 of its text: a blob
 * (a file's bytes), a tree (a line an entry: f a file, x one that can
 * be run, d a directory, c a conflict with its three versions), a
 * commit (a tree, its parents, a date, an author, a message) and an
 * operation (the one before, what was done, the current branch, every
 * branch's commit). A hash names its object and all that is under it:
 * two commits with the same tree hash have the same files, a subtree
 * that did not change is stored once, and head's 40 digits are the
 * whole repository with its past.
 *
 * The objects' text is this file's own, canonical and readable
 * ("tree\nf HASH name\n..."), hashed by SHA-1 (lib_crypto), deflated
 * (lib_compression). Dropped: git's formats, packs and deltas, the
 * protocol, the index, submodules and links, rename detection,
 * tags, rebase.
 *
 * The tests: TinyVCS_test.sh checks the laws (a switch restores a
 * commit's tree exactly; a merge of disjoint changes is symmetric and
 * holds both; undo restores the branches; a clone has the same log)
 * and diff against GNU patch (applying the diff gives the new file).
 *
 * Exercises, each cheap because the repository is objects that never
 * change, named by their hash, and its state an operation among them
 * (redo needs none: undo is an operation, so an undo undone is a redo):
 * - time travel: log @3 or switch @3, the repository as it was three
 *   operations ago; each operation still holds its branches, so it is
 *   following prev three times;
 * - collection: copy what the operations kept still reach into a new
 *   file, and rename it over the old one (TinyDatabase's compaction);
 *   the rename is atomic, so a crash leaves the old file whole;
 * - two commands at once: head is replaced by a rename, the last one
 *   wins and the other's operation is lost; re-read head before the
 *   rename, and if it moved, record an operation with both as its
 *   parents, their branches merged (jj's concurrent operations, merged
 *   rather than locked out);
 * - renames seen: a file gone and a file new with the same hash are one
 *   file moved, content addressing says it for nothing;
 * - patience diff beside Myers': the lines unique to both sides as
 *   anchors, then Myers between them (Bram Cohen's, 2005), often a more
 *   readable diff of code;
 * - a lazy clone: copy the operations and commits, and fetch a blob
 *   from the source only when read; a hash names it wherever it is.
 *
 * Where it stands: Sha1 and Zlib are ix's libraries (lib_crypto,
 * lib_compression), mini-git's too, and Zlib.mli says what a deflated
 * object is. mini-git's Object, Loose, Pack and Index9 are git's own
 * formats for what is here one text and one file. A file that is only
 * appended to and a small write that commits are TinyDatabase's;
 * TinyBuildSystem's stamps are digests of contents for the same
 * reason as here, a name that cannot be stale.
 *
 * cs-history:
 * Version control went from one file to one tree to one graph. SCCS
 * (Marc Rochkind, Bell Labs, 1972) and RCS (Walter Tichy, 1982) kept
 * the versions of a file, as deltas, with a lock for who edits. CVS
 * and Subversion (2000) versioned a tree on a server, and merged
 * where the others locked. BitKeeper gave each developer a whole
 * repository; Linux used it from 2002 until its free licence was
 * withdrawn in April 2005, and within weeks Linus Torvalds had
 * written git and Matt Mackall Mercurial. Naming everything by the
 * hash of its content was Monotone's (Graydon Hoare, 2003), which
 * Torvalds found right in idea and too slow.
 *
 * terminology:
 * A commit here, as in git, is a snapshot: a whole tree. A diff is
 * computed when asked, between two trees, and a merge from three.
 * The systems of the other family (Darcs, Pijul) store the changes,
 * patches, and a version is the patches applied; they can say that
 * two histories are the same changes in another order, which a
 * graph of snapshots cannot. Storing deltas to save space, as RCS
 * and git's packs do, is another matter: a way to write snapshots.
 *
 * plan9-is-cleaner:
 * A store where a block's address is the hash of its bytes, written
 * once and never changed, is Plan 9's Venti (Sean Quinlan and Sean
 * Dorward, 2002), under its file server Fossil: a snapshot of a file
 * system is one hash, taken each night, and two that share files
 * share blocks. git is that idea for source code, with a commit
 * where Venti has a root.
 *
 * References: E. W. Myers, "An O(ND) Difference Algorithm and Its
 * Variations" (Algorithmica, 1986; from memory); S. Khanna, K. Kunal and
 * B. C. Pierce, "A Formal Investigation of Diff3" (FSTTCS, 2007; from
 * memory); M. von Zweigbergk, Jujutsu (jj, 2019-; from memory), the
 * working copy as a commit, the operation log and first-class
 * conflicts; L. Torvalds, git (2005), the object model; R. C. Merkle,
 * "A Digital Signature Based on a Conventional Encryption Function"
 * (CRYPTO, 1987; from memory), the tree of hashes; B. Cohen, patience
 * diff (2005; from memory). *)

(* a command and its arguments, done in the repository found from the
 * current directory: init, commit, log, diff, switch, merge, undo... *)
val run : < Cap.env; Cap.open_in; Cap.open_out; Cap.stdout > -> string list -> unit
