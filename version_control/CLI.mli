(* mini-git: git, after git9 (Ori Bernstein's git for Plan 9, in
 * 9front): the same repositories as git's, read and written, with
 * git9's fewer commands and their output.
 *
 * A repository is a store of objects, each named by the SHA-1 of its
 * bytes (Hash), and a few names for some of them (Refs):
 *
 *     refs/heads/master
 *            |
 *            v
 *        commit C2 ----parent----> commit C1          who, when, why
 *            | tree                    | tree
 *            v                         v
 *         tree T2                   tree T1           a directory:
 *          |- README --> blob B1 <-- README -|        names and hashes
 *          |- lib ----> tree T4      lib ---> tree T3
 *                        |- a.c --> blob B3   |- a.c --> blob B2
 *
 * C2 changed lib/a.c. It has a new blob for it, a new tree for lib
 * and a new one for the root, and nothing else: README's blob is the
 * one C1 has. An object is never changed, since its name is its
 * content's hash; and as a tree holds its entries' hashes and a
 * commit its tree's and its parents', a commit's name fixes every
 * byte of every file of all the history behind it. A branch is a
 * file with forty hexadecimal digits in it.
 *
 * Its modules, from the store up:
 *
 *     Hash, Object       a name; the four kinds parsed and printed
 *     Loose, Pack, Delta where objects are: a file each, or many in
 *     Store              one file as differences; both behind Store
 *     Refs, Repo, Conf   the names, the .git found, its config
 *     Index9, Walk, Save the work tree: what changed; a commit made
 *     Query, Log, Fs     history: a..b, the ancestors, as paths
 *     Diff, Merge3       two texts compared; two changes joined
 *     Proto, Get, Send,  the other repository: what it has, what it
 *     Serve, Packer      lacks, packed and sent
 *     Commands, CLI      git9's scripts and programs, by name
 *
 * cs-history:
 * Version control went from the file to the tree to the copy. SCCS
 * (Marc Rochkind, Bell Labs, 1972) and RCS (Walter Tichy, 1982) keep
 * one file's versions, as differences, and a lock while it is
 * edited; CVS (from 1986) kept RCS files together for a whole tree,
 * later on a server, and merged where they had locked; Subversion
 * (2000) made the commit one change to the tree. All have one repository that
 * everyone writes to. In the distributed systems each copy has the
 * whole history and commits to itself, and histories are merged:
 * BitKeeper, which Linux used from 2002, then, in the same weeks of
 * April 2005 when its free use ended, Mercurial (Matt Mackall) and
 * git (Linus Torvalds), who called it "the stupid content tracker":
 * a store of content by hash first, the commands on top later.
 * Junio Hamano has maintained it since that July.
 *
 * plan9-is-cleaner:
 * git9 (2019: from memory) is not a port. It keeps the format, so
 * that it clones from any server, and little else: a few C programs
 * for what must be fast (the objects, the walk, the protocol), rc
 * scripts for the commands (Commands follows them line for line), no
 * staging area with content in it (Index9), and the history served
 * as a file system, so that the tools to look at an old version are
 * ls, cat and diff (Fs). 8,000 lines of C where git has several
 * hundred thousand.
 *
 * The command line: mini-git CMD args, git9's programs and scripts,
 * git/CMD on Plan 9, as subcommands of one executable; how: [help]
 * in CLI.ml, what mini-git -h prints.
 *
 * References: git's own "Git User's Manual" and gitcore-tutorial,
 * for the objects; Scott Chacon's "Pro Git", chapter 10, "Git
 * Internals"; git9's git(1) and its source in principia; M. J.
 * Rochkind, "The Source Code Control System" (IEEE Transactions on
 * Software Engineering, 1975); W. F. Tichy, "RCS -- A System for
 * Version Control" (Software: Practice and Experience, 1985);
 * plan_vcs.md, for what differs from git9 and why. *)

type caps = < Store.caps; Cap.stdout; Cap.stderr; Cap.argv; Cap.fork; Cap.exec; Cap.wait >

val main : < caps; .. > -> int
