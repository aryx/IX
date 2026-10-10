(* A tiny build system: the idea of make (Stuart Feldman, 1976) and mk
 * (Andrew Hume, 1987) -- describe the dependencies between files
 * concisely, and maintain them efficiently -- without their language.
 * mini-mk (builder/) is mk, faithfully; this is what is left when
 * compatibility is dropped and only the idea is kept.
 *
 * A Buildfile has five kinds of lines, shown by example in [help]
 * below, what tiny-build -h prints with the usage; and that is all the
 * syntax. Variables are expanded in rule lines as
 * they are read; a recipe gets them, and $target, $prereq and $stem,
 * in its environment, so the shell expands them and there is no second
 * expansion language. There are no attributes: a target whose recipe
 * makes no file (clean, all) is simply never up to date.
 *
 * {b Up to date by content, not by time.} Each target's stamp is a
 * digest of its recipe and of its prerequisites' contents:
 *
 *     stamp(hello) = sha1(recipe, "hello.o", sha1(hello.o), "world.o", ...)
 *
 * (SHA-1, lib_crypto's Sha1, which tiny-vcs has in t-ix already; it
 * was MD5.) For [help]'s Buildfile the graph under hello is
 *
 *     hello                 a recipe: cc -o $target $prereq
 *      |-- hello.o          the pattern's, its stem hello: cc -c $stem.c
 *      |    '-- hello.c     a source: a file no rule makes
 *      '-- world.o          the pattern's, its stem world
 *           '-- world.c     a source
 *
 * and a comment added to world.c goes this far and no further: its
 * digest is another, so world.o's stamp is another and cc -c runs; the
 * world.o that comes out has the bytes it had, so its digest, which is
 * its file's and not its stamp, is the same; hello's stamp, made of
 * that digest, is the one kept in .tiny-build, and hello is up to
 * date. A program's way through this file is as short: the Buildfile's
 * lines to rules ([parse]), the rules to the graph under the target
 * ([graph], which also chooses the pattern), the graph to a list with
 * prerequisites first ([order]), and the list to recipes ([build]).
 *
 * The stamps of the last build are kept in .tiny-build; a target is
 * rebuilt when it is missing or its stamp changed. That is the
 * "verifying traces" rebuilder of Mokhov, Mitchell and Peyton Jones,
 * "Build Systems a la Carte" (2018), and it removes three of mk's
 * problems at once: two files made in the same second are not "equal",
 * a git checkout's new times rebuild nothing, and a recipe that
 * regenerates an identical file stops the rebuild there (early cutoff)
 * without mk's cmp -s trick.
 *
 * {b One pass, no re-walk.} mk walks its whole graph again after every
 * job, because a recipe's effect is known only by looking at the file
 * again. Here a node is decided when it becomes ready -- when all its
 * prerequisites are done and their digests known -- so one topological
 * pass does, with -j N jobs at a time (Kahn, 1962, as a scan of the
 * nodes left: the simple version, quadratic, fine for hundreds):
 *
 *     todo  = the nodes under the target, prerequisites first
 *     loop: start every todo node whose prerequisites are done,
 *             while fewer than N jobs run
 *           a node that is up to date, or has no recipe, is done now
 *           otherwise wait for a job to end; its node is done
 *
 * {b What it checks}, before running anything: a cycle (reported with
 * its path, a -> b -> a), two pattern rules that could both make a
 * target (ambiguous), a target nothing knows how to make, and infinite
 * patterns (%: %.gz is used at most once on a path).
 *
 * <file includes a file, if it exists (a generated .depend may not, the
 * first time), and a backslash-newline continues a line, as ocamldep
 * writes them: that is enough for a Buildfile of 13 lines to build
 * mini-mk's ten modules from ocamldep's output, with -j 4 in about a
 * second. There, a comment added to Recipe.ml recompiles Recipe.ml
 * only: its object comes out identical, so nothing is relinked.
 *
 * What it deliberately does not do, to stay tiny: quoting (names cannot
 * contain blanks), ${X:%.c=%.o} substitutions, one recipe
 * making several targets at once (a b: c runs the recipe once per
 * target), archives, and mk's -t, -w, -k, -e. The digests are
 * recomputed at each run, reading every input: the price of not
 * trusting times. A file named like a virtual target (a file "clean")
 * makes it look like a real one.
 *
 * Exercises: add ${X:%.c=%.o}; make the stamp of a source file its
 * (mtime, size) when unchanged since the last run, to avoid reading
 * it again; replace the scan by pending counts per node and measure
 * the difference; let a recipe declare the dependencies it discovered
 * (redo's redo-ifchange), which the one-pass scheduler can take if a
 * node is decided again after its new prerequisites are done.
 *
 * Where it stands: ix itself is built by mini-mk (Builder's mkfiles,
 * and dune beside it), whose recipes mini-rc or tiny-shell run; this
 * one hands a recipe to sh -e. The digest is Sha1's, which names
 * TinyVCS's objects too: a file's content as its name is the same
 * idea in both, and in TinyDatabase's nodes that never change. The
 * children are Procs's (wait_any), the loop mini-mk and the shells
 * have around wait.
 *
 * cs-history:
 * Stuart Feldman wrote make at Bell Labs in 1976 after a colleague
 * lost a morning debugging a program that was already fixed: the fix
 * had not been recompiled (the story is his, told in Eric Raymond's
 * The Art of Unix Programming). The tab that must start
 * a recipe's line was an accident of its first lex input, and he kept
 * it because make already had a dozen users (the same source): the
 * first compatibility kept, in a tool of a weekend.
 * Here a recipe's line starts with any blank.
 *
 * wib:
 * make compares two times, the target's and a prerequisite's: one
 * stat each, nothing kept between runs, nothing read. It is wrong
 * when a clock is, when a file is restored with an old date, when two
 * files are written in the same second, and it rebuilds all that is
 * above a file touched and not changed. It won for thirty years on
 * that one stat. A digest reads every file at every run and needs a
 * file of its own (.tiny-build) that can be lost or stale; it is
 * right in those four cases.
 *
 * others:
 * The build systems since make chose among the same few parts (the
 * paper's point): redo (D. J. Bernstein's design, undated; Avery
 * Pennarun's program, 2010) has no file of rules, a target's recipe
 * is a script that says what it read as it runs; ninja (Evan Martin,
 * for Chrome, 2012) keeps make's times and the recipes' text and is
 * written by another program, not by hand; Bazel (Google's Blaze,
 * open in 2015) and Nix name what is built by a digest of all that
 * went in, and so share it between machines; Shake (Neil Mitchell,
 * 2012) is a Haskell library with the verifying traces this file has.
 *
 * References: Stuart Feldman, "Make -- A Program for Maintaining
 * Computer Programs" (Software: Practice and Experience, 1979), the
 * idea: "The description file really defines the graph of
 * dependencies"; Andrew Hume, "Mk: a Successor to Make" (USENIX,
 * 1987), for % rules and recipes run in parallel; A. B. Kahn,
 * "Topological sorting of large networks" (CACM, 1962): take a node
 * whose predecessors are all done, repeat, and what is left at the end
 * is a cycle -- the scheduler's loop, with the cycles reported
 * earlier, by the walk that builds the graph; Andrey Mokhov, Neil
 * Mitchell and Simon Peyton Jones, "Build Systems a la Carte" (ICFP
 * 2018), for the verifying traces. *)

(* a rule of the file; a target with what it is made from and how *)
type rule
type node

(* from a target to its node, and its prerequisites' under it: the rules
 * naming it, or the one pattern rule whose prerequisites can be made *)
val graph : rule list -> exists:(string -> bool) -> string -> node

(* the program: its arguments (-h: how) to its exit status *)
val main : Cap.all_caps -> int
