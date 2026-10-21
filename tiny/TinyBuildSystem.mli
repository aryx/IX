(* A tiny build system. It keeps the idea of make (Stuart Feldman,
 * 1976) and mk (Andrew Hume, 1987) -- describe the dependencies between
 * files concisely, and maintain them efficiently -- but not their
 * language.
 *
 * The full-size version in ix, mini-mk (builder/), is a faithful copy
 * of mk; this one is what remains when compatibility is dropped and
 * only the idea is kept.
 *
 * A Buildfile has five kinds of lines, shown by example in the
 * [help] string of the .ml (which build -h prints along with the
 * usage), and
 * that is the whole syntax. Variables in rule lines are expanded as
 * the lines are read. A recipe receives the variables, plus $target,
 * $prereq and $stem, in its environment (on tiny-kernel, which has
 * none, as the shell's assignments before the recipe), so the shell
 * does the expansion and there is no second expansion language. There
 * are no
 * attributes: a target whose recipe creates no file (clean, all) is
 * simply never up to date.
 *
 * {b Up to date by content, not by time.} The stamp of each target is
 * a digest of its recipe and of the contents of its prerequisites:
 *
 *     stamp(hello) = sha1(recipe, "hello.o", sha1(hello.o), "world.o", ...)
 *
 * (The digest is SHA-1, Sha1's, which tiny-vcs uses too; it used to
 * be MD5.) For the Buildfile in [help],
 * the graph under hello is:
 *
 *     hello                 has its own recipe: cc -o $target $prereq
 *      |-- hello.o          made by the pattern rule, with stem hello:
 *      |    |                 cc -c $stem.c
 *      |    '-- hello.c     a source: a file that no rule makes
 *      '-- world.o          made by the pattern rule, with stem world
 *           '-- world.c     a source
 *
 * Adding a comment to world.c propagates exactly this far and no
 * further. The digest of world.c changes, so the stamp of world.o
 * changes and cc -c runs. But the new world.o has the same bytes as
 * before, so its digest (the digest of the file, not its stamp) is
 * unchanged. The stamp of hello, computed from that digest, is then
 * the same as the one stored in .tiny-build, and hello is up to date.
 *
 * The path through this file is just as short: the lines of the
 * Buildfile become rules ([parse]), the rules become the graph under
 * the target ([graph], which also chooses the pattern rule), the graph
 * becomes a list with prerequisites first ([order]), and the list is
 * turned into recipes run ([build]).
 *
 * The stamps of the last build are stored in .tiny-build; a target is
 * rebuilt when it is missing or when its stamp has changed. This is the
 * "verifying traces" rebuilder of Mokhov, Mitchell and Peyton Jones,
 * "Build Systems a la Carte" (2018), and it fixes three problems of mk
 * at once: two files written in the same second are no longer
 * considered "equal", the new timestamps from a git checkout do not
 * trigger any rebuild, and a recipe that regenerates an identical file
 * stops the rebuild there (early cutoff), without mk's cmp -s trick.
 *
 * {b One pass, no re-walk.} mk walks its whole graph again after every
 * job, because the only way to know what a recipe did is to look at
 * the file again. Here a node is decided when it becomes ready, that is
 * when all its prerequisites are done and their digests are known. So a
 * single topological pass is enough, running up to N jobs at a time
 * with -j N. It is Kahn's algorithm (1962), implemented as a scan of
 * the remaining nodes: the simple, quadratic version, which is fine for
 * hundreds of nodes:
 *
 *     todo  = the nodes under the target, prerequisites first
 *     loop: start every todo node whose prerequisites are done,
 *             while fewer than N jobs run
 *           a node that is up to date, or has no recipe, is done now
 *           otherwise wait for a job to end; its node is done
 *
 * {b What it checks} before running anything: cycles (reported with
 * their path, a -> b -> a), two pattern rules that could both make the
 * same target (ambiguity), a target that nothing knows how to make,
 * and infinite patterns (a rule like %: %.gz is used at most once on a
 * path).
 *
 * The line <file includes a file if it exists (a generated .depend may
 * not exist the first time), and a backslash-newline continues a line,
 * which is how ocamldep writes its output. That is enough for a
 * 13-line Buildfile to build the ten modules of mini-mk from the output
 * of ocamldep, with -j 4, in about a second. In that build, adding a
 * comment to Recipe.ml recompiles only Recipe.ml: its object file comes
 * out identical, so nothing is relinked.
 *
 * What it deliberately does not do, to stay tiny: quoting (names cannot
 * contain blanks), ${X:%.c=%.o} substitutions, a single recipe making
 * several targets at once (a b: c runs the recipe once per target),
 * archives, and mk's -t, -w, -k and -e options. A file is read for its
 * digest once a run, and not at all when its size and date are the
 * ones .tiny-build recorded with its digest, as git's index does: the
 * date says only "unchanged", never "newer", and a digest is recorded
 * only for a file dated before the second it was read in (one written
 * again within it, at the same size, would keep its date: git's "racy"
 * files). A file that has the name of a virtual target
 * (a file called "clean") makes that target look like a real one.
 *
 * Exercises: add ${X:%.c=%.o}; replace the scan with a count of pending
 * prerequisites per node, and measure the difference; let a recipe
 * declare the
 * dependencies it discovered while running (like redo's redo-ifchange),
 * which the one-pass scheduler can support if a node is decided again
 * once its new prerequisites are done.
 *
 * Where it stands: ix itself is built by mini-mk (with Builder's
 * mkfiles, and dune alongside), whose recipes are run by mini-rc or
 * tiny-shell; this one hands each recipe to the system's shell
 * (TinyLibSystem.shell: sh -e on the host, tiny-shell's rc -e on
 * tiny-kernel, so a recipe is in that shell's language). The digest comes
 * from Sha1, which also names the objects of TinyVCS: using the
 * content of a file as its name is the same idea in both, and in the
 * nodes of TinyDatabase, which never change either. The child
 * processes are waited for by TinyLibSystem.wait_any (Procs's on the
 * host), the same loop around wait that mini-mk and the shells use.
 *
 * cs-history:
 * Stuart Feldman wrote make at Bell Labs in 1976 after a colleague
 * lost a morning debugging a program that was already fixed: the fix
 * had simply not been recompiled (the story is his, told in Eric
 * Raymond's The Art of Unix Programming). The tab that must start each
 * line of a recipe was an accident of the first lex input he wrote, and
 * he kept it because make already had a dozen users (same source): the
 * first backward compatibility, in a tool written over a weekend. Here
 * a recipe line can start with any blank.
 *
 * wib:
 * make compares two times, the time of the target and the time of a
 * prerequisite: one stat call each, nothing stored between runs,
 * nothing read. It gets things wrong when a clock is wrong, when a file
 * is restored with an old date, or when two files are written in the
 * same second, and it rebuilds everything above a file that was touched
 * but not changed. It won for thirty years on the strength of that one
 * stat. A digest has to read a file once (then its size and date
 * stand for it, which only says it did not change), and needs a file of
 * its own (.tiny-build) that can be lost or become stale; but it is
 * right in those four cases.
 *
 * others:
 * The build systems that came after make all chose among the same few
 * parts (which is the point of the paper). redo (designed by D. J.
 * Bernstein, undated; implemented by Avery Pennarun, 2010) has no rules
 * file: the recipe for a target is a script that declares what it read
 * as it runs. ninja (Evan Martin, for Chrome, 2012) keeps make's
 * timestamps plus the text of the recipes, and its files are generated
 * by another program, not written by hand. Bazel (Google's Blaze, open
 * sourced in 2015) and Nix name each build output by a digest of
 * everything that went into it, so outputs can be shared between
 * machines. Shake (Neil Mitchell, 2012) is a Haskell library that uses
 * verifying traces, as this file does.
 *
 * References:
 *  - Stuart Feldman, "Make -- A Program for Maintaining Computer
 *    Programs" (Software: Practice and Experience, 1979): the idea,
 *    "The description file really defines the graph of dependencies"
 *  - Andrew Hume, "Mk: a Successor to Make" (USENIX, 1987): % rules
 *    and recipes run in parallel
 *  - A. B. Kahn, "Topological sorting of large networks" (CACM, 1962):
 *    take a node whose predecessors are all done, repeat, and whatever
 *    is left at the end is a cycle. This is the scheduler's loop; here
 *    cycles are reported earlier, by the walk that builds the graph
 *  - Andrey Mokhov, Neil Mitchell and Simon Peyton Jones, "Build
 *    Systems a la Carte" (ICFP 2018): verifying traces
 *)

(* a rule of the file; a target with what it is made from and how *)
type rule
type node

(* [graph rules exists target]: from a target to its node, and its
 * prerequisites' under it: the rules naming it, or the one pattern rule
 * whose prerequisites can be made; exists says whether a file is there *)
val graph : rule list -> (string -> bool) -> string -> node

(* the program: its arguments (-h: how) to its exit status *)
val main : Cap.all_caps -> int
