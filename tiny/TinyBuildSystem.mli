(* A tiny build system. It keeps the idea of make (Stuart Feldman,
 * 1976) and mk (Andrew Hume, 1987) -- describe the dependencies between
 * files concisely, and maintain them efficiently -- and most of mk's
 * language: a Buildfile is a subset of its core.
 *
 * A Buildfile has five kinds of lines, shown by example in the
 * [help] string of the .ml (which build -h prints along with the
 * usage), and that is the whole syntax. Variables in rule lines are
 * expanded as the lines are read. This includes ${X:from=to}, mk's
 * substitution: each word of X that matches from, where % matches any
 * part, is turned into to, as in LIB = ${CORE:%=lib/%.tmi}. A recipe
 * receives the variables, plus $target, $prereq and $stem, in its
 * environment. tiny-kernel has no environment, so there they are
 * passed as shell assignments placed before the recipe. Either way the
 * shell does the expansion, and there is no second expansion
 * language.
 *
 * twin:
 * mini-mk (builder/), ix's full-size version, is a faithful copy of mk.
 * This one is what remains when compatibility is dropped: mk's core,
 * plus a target that is out of date because of its content, not its
 * time.
 *
 * kept:
 * {b What it checks} before running anything: cycles (reported with
 * their path, a -> b -> a), two pattern rules that could both make the
 * same target (ambiguity), a target that nothing knows how to make, and
 * infinite patterns (a rule like %: %.gz is used at most once on a
 * path).
 *
 * It keeps mk's two wildcards, % and & (a stem with no / or .), for two
 * kinds of rules. A rule whose recipe is the same everywhere is written once
 * with %, and its stem crosses directories: tiny/Buildfile's %.o: %.c
 * makes runtime/c/libc.o and user/get.o, and its %.tmi: %.o
 * makes TinyML/Lexer.tmi. A rule whose recipe depends on the directory
 * is written with &: tiny-ml's parts are compiled with -I TinyML and
 * the top's units without it, so TinyML/&.o and &.o each make their own
 * directory's objects. With two % rules instead, %.o and TinyML/%.o
 * would both match TinyML/Lexer.o, which is ambiguous. The . keeps &.o
 * from making x.start.o (stem x.start), which %.start.o makes. A % that
 * never crossed a / would need no &, but each rule of the first kind
 * would then be written again for each directory (about ten rules in
 * tiny/Buildfile), and the file would no longer be mk's. & is needed
 * because one Buildfile makes all of tiny/'s directories. xix's omk
 * leaves it out ("rarely found used, % is enough"), and indeed, with a
 * mkfile in each directory, as Plan 9 has them, % is enough.
 *
 * The line <file includes a file if it exists (a generated .depend may
 * not exist the first time), and a backslash-newline continues a line,
 * which is how ocamldep writes its output. That is enough for a 13-line
 * Buildfile to build the ten modules of mini-mk from the output of
 * ocamldep, with -j 4, in about a second. In that build, adding a
 * comment to Recipe.ml recompiles only Recipe.ml: its object file comes
 * out identical, so nothing is relinked.
 *
 * dropped:
 * To stay tiny, it leaves out:
 * - mk's attributes. A target whose recipe creates no file, such as
 *   clean or all, is simply never up to date; but a file with its name,
 *   a file called "clean", makes it look like a real target.
 * - regular-expression rules;
 * - quoting (names cannot contain blanks);
 * - a single recipe making several targets at once (a b: c runs the
 *   recipe once per target);
 * - archives, and mk's -t, -w, -k and -e options.
 *
 * It also leaves out mk's backquotes, which turn a command's output into
 * the words of a variable (as in mini-mk's builder/mkfile: LOCAL=`{ls
 * *.ml *.mli}), because they need a shell to run while the file is
 * read. What that costs, on an example: tiny/Buildfile cannot say "the
 * image's /examples is every source in examples/" (EXAMPLES=`{ls
 * examples/*.c examples/*.ml ...}). Its recipe globs them with rc
 * instead, so they are not prerequisites: changing only an example
 * does not rebuild the image.
 *
 * twist:
 * {b Up to date by content, not by time.} The stamp of each target is a
 * digest of its recipe and of the contents of its prerequisites:
 *
 *     stamp(hello) = sha1(recipe, "hello.o", sha1(hello.o), "world.o", ...)
 *
 * For the Buildfile in [help], the graph under hello is:
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
 * unchanged. The stamp of hello, computed from that digest, is then the
 * same as the one stored in .tiny-build, and hello is up to date.
 *
 * The stamps of the last build are stored in .tiny-build; a target is
 * rebuilt when it is missing or when its stamp has changed. This is the
 * "verifying traces" rebuilder of Mokhov, Mitchell and Peyton Jones,
 * "Build Systems a la Carte" (2018), and it fixes four problems of mk
 * at once:
 * - two files written in the same second are no longer considered
 *   "equal";
 * - the new timestamps from a git checkout do not trigger any rebuild;
 * - a recipe that regenerates an identical file stops the rebuild there
 *   (early cutoff), without mk's cmp -s trick;
 * - when a recipe is edited, or one of its variables changes (CFLAGS),
 *   what it makes is remade, since the recipe is in the stamp with the
 *   values of its variables. make and mk see neither change. A Makefile
 *   fakes it by making every target depend on the Makefile, which
 *   remakes everything, or with boilerplate that saves each command
 *   line to compare it later (Linux's kbuild, with its .cmd files and
 *   if_changed).
 *
 * A file is read for its digest at most once per run, and not at all
 * when its size and date are the ones .tiny-build recorded along with
 * its digest, as git's index does. The date only ever means
 * "unchanged", never "newer". A digest is recorded only for a file
 * dated before the second in which it was read: a file written again
 * within that same second, with the same size, would keep the same
 * date (these are git's "racy" files).
 *
 * {b One pass, no re-walk.} mk walks its whole graph again after every
 * job, because the only way to know what a recipe did is to look at the
 * file again. Here a node is decided when it becomes ready, that is
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
 * archi:
 * The path through this file is short: the lines of the Buildfile
 * become rules ([parse]), the rules become the graph under the target
 * ([graph], which also chooses the pattern rule), the graph becomes a
 * list with prerequisites first ([order]), and the list is turned into
 * recipes run ([build]).
 *
 * context:
 * ix itself is built by mini-mk (with Builder's mkfiles, and dune
 * alongside), whose recipes are run by mini-rc or tiny-shell. This one
 * hands each recipe to rc -e (TinyLibSystem.shell, which is tiny-shell
 * on the host and /bin/rc on tiny-kernel), so a recipe is rc code on
 * both, as mini-mk's recipes are with mini-rc. The digest comes from
 * Sha1, which also names the objects of TinyVCS. Naming something by
 * its content is the same idea in both, and it is also the idea behind
 * the nodes of TinyDatabase, which never change either. The child
 * processes are waited for by TinyLibSystem.wait_any (on the host, it
 * is the wait_any of Procs), the same loop around wait that mini-mk and
 * the shells use.
 *
 * exercises:
 * - add ${X:%.c=%.o};
 * - replace the scan with a count of pending prerequisites per node,
 *   and measure the difference;
 * - let a recipe declare the dependencies it discovered while running
 *   (like redo's redo-ifchange). The one-pass scheduler can support it
 *   if a node is decided again once its new prerequisites are done.
 *
 * cs-history:
 * Stuart Feldman wrote make at Bell Labs in 1976 after a colleague
 * lost a morning debugging a program that was already fixed: the fix
 * had simply not been recompiled (the story is his, told in Eric
 * Raymond's The Art of Unix Programming). The tab that must start each
 * line of a recipe was an accident of the first lex input he wrote, and
 * he kept it because make already had a dozen users (the same source
 * tells this). It was the first case of backward compatibility, in a
 * tool written over a weekend. Here a recipe line can start with any
 * blank.
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
 * others:
 * GNU make (since 3.82) settles two pattern rules that match the same
 * target by the stem: the shorter one, the more specific rule, wins, so
 * TinyML/%.o beats %.o with no & at all. It would be three lines here,
 * but a Buildfile would then mean something else under mk and mini-mk,
 * which have no such rule, and a rule added anywhere could silently
 * take targets from a more general one, where here two candidates are
 * an error (see What it checks, under kept:).
 *
 * wib:
 * make compares two times, the time of the target and the time of a
 * prerequisite. That takes one stat call each; nothing is stored
 * between runs, and no file is read. It gets things wrong when a clock
 * is wrong, when a file is restored with an old date, or when two files
 * are written in the same second, and it rebuilds everything above a
 * file that was touched but not changed. It won for thirty years on the
 * strength of that one stat. A digest has to read a file once (after
 * that, its size and date stand for it, and they only tell that it did
 * not change), and it needs a file of its own (.tiny-build) that can be
 * lost or become stale; but it is right in those four cases.
 *
 * references:
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
 *  - principia's builders/mk, the C code of mk, which mini-mk follows:
 *    graph.c makes the graph (with cyclechk and ambiguous, the checks
 *    above), and mk.c's loop calls work on the whole graph again after
 *    each waitup, the re-walk this file does without
 *)

(* A node is a target with what it is made from and how. *)
type rule
type node

(* [graph rules exists target] returns the target's node, made from the
 * rules that name it, or else from the one pattern rule whose
 * prerequisites can be made. exists says whether a file is at a path.
 * A node's name is a string, since a target like all is no file. *)
val graph : rule list -> (Fpath.t -> bool) -> string -> node

type caps =
  < Cap.forkew; Cap.env; Cap.open_in; Cap.open_out;
    Cap.readdir; Cap.clock; Cap.stdout; Cap.stderr >

(* The arguments start with the program's name; -h tells how. *)
val main : < caps; .. > -> string array -> Exit.t
