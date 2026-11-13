(* mini-git is git, after git9 (Ori Bernstein's git for Plan 9, in
 * 9front). It reads and writes the same repositories as git, with
 * git9's smaller set of commands and git9's output.
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
 * C2 changed lib/a.c. It has a new blob for that file, a new tree for
 * lib and a new tree for the root, and nothing else: README's blob is
 * the same one that C1 has. An object is never changed, since its name
 * is the hash of its content. A tree holds the hashes of its entries,
 * and a commit holds the hash of its tree and of its parents, so a
 * commit's name fixes every byte of every file in all the history
 * behind it. A branch is a file with forty hexadecimal digits in it.
 *
 * Here are its modules, from the store up:
 *
 *     Hash, Object       a name; the four kinds, parsed and printed
 *     Loose, Pack, Delta where objects are: one file each, or many in
 *     Store              one file as differences; Store hides both
 *     Refs, Repo, Conf   the names; finding the .git; its config
 *     Index9, Walk, Save the work tree: what changed; making a commit
 *     Query, Log, Fs     history: a..b, the ancestors, as paths
 *     Diff, Merge3       comparing two texts; joining two changes
 *     Proto, Get, Send,  the other repository: what it has, what it
 *     Serve, Packer      lacks, and how to pack it and send it
 *     Commands, CLI      git9's scripts and programs, by name
 *
 * cs-history:
 * Version control went from the file to the tree to the copy. SCCS
 * (Marc Rochkind, Bell Labs, 1972) and RCS (Walter Tichy, 1982) keep
 * the versions of one file, as differences, and a lock on the file
 * while it is edited. CVS (from 1986) kept RCS files together for a
 * whole tree, later on a server, and it merged changes where RCS
 * locked. Subversion (2000) made the commit one change to the
 * whole tree. All of them have one repository that everyone writes
 * to. In the distributed systems, each copy has the whole history and
 * commits to itself, and histories are merged. BitKeeper came first,
 * and Linux used it from 2002. Then, in the same weeks of April 2005
 * when its free use ended, came Mercurial (Matt Mackall) and git
 * (Linus Torvalds). Torvalds called git "the stupid content tracker":
 * it was a store of content by hash first, and the commands came on
 * top later. Junio Hamano has maintained it since that July.
 *
 * plan9-is-cleaner:
 * git9 (2019) is not a port. It keeps the format, so that it can
 * clone from any server, and little else. It has a few C programs for
 * what must be fast (the objects, the walk, the protocol), and rc
 * scripts for the commands (Commands follows them line for line). Its
 * index has no staging area with content in it (Index9), and it
 * serves the history as a file system, so that the tools to look at
 * an old version are ls, cat and diff (Fs). It has 9,000 lines of C,
 * where git has several hundred thousand.
 *
 * The command line is mini-git CMD args. The commands are git9's
 * programs and scripts, git/CMD on Plan 9, made subcommands of one
 * executable. [help] in CLI.ml, which mini-git -h prints, shows how
 * to use them.
 *
 * References: git's own "Git User's Manual" and gitcore-tutorial,
 * for the objects; Scott Chacon's "Pro Git", chapter 10, "Git
 * Internals"; git9's git(1) and its source in principia; M. J.
 * Rochkind, "The Source Code Control System" (IEEE Transactions on
 * Software Engineering, 1975); W. F. Tichy, "RCS -- A System for
 * Version Control" (Software: Practice and Experience, 1985);
 * plan_vcs.md, for what differs from git9 and why. *)

type caps =
  < Store.caps; Cap.stdout; Cap.stderr; Cap.argv; Cap.fork; Cap.exec; Cap.wait;
    Cap.pipe >

val main : < caps; .. > -> int
