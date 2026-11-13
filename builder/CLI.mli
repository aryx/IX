(* mini-mk: Plan 9's mk. A mkfile says what each file is made from
 * and by which commands. mk finds the files that are older than what
 * they are made from, and runs those commands and no others, several
 * at a time, in an order that respects the dependencies.
 *
 *     OBJS=hello.5 world.5
 *     hello: $OBJS
 *         5l -o $target $prereq                 the graph, from hello
 *     %.5: %.c                                           hello
 *         5c -c $stem.c                                 /     \
 *                                                 hello.5     world.5
 *     $ touch world.c; mk                            |           |
 *     5c -c world.c                               hello.c     world.c
 *     5l -o hello hello.5 world.5                             (newer)
 *
 * world.c is newer than world.5, so world.5 is remade, and is then
 * newer than hello; hello.5 is left alone. The whole program is that
 * walk, which compares a file's date with the dates of what it is made
 * from.
 *
 *     mkfile, var=value                 the modules, in a build's order
 *        | Mkfile     reads it once, evaluating each line as it is read,
 *        |            into variables and rules
 *        |-- Word     splits a line's text into words, expanding $X
 *        |-- Pattern  matches a rule's target: literal, %, &, a regexp
 *     rules
 *        | Graph      finds, from a target, the rules that apply, down to
 *        |            the files that only exist
 *     nodes and arcs
 *        | Build      walks the graph: what is ready and out of date gets
 *        |            a job, and the walk starts again after each job
 *        |-- Outofdate  compares a node with a prerequisite by their dates
 *        |-- Archive    gives the date of lib.a(member)
 *        '-- Recipe     sets a job's variables, forks the shell, waits
 *
 * Only this module and Recipe touch the system. Mkfile and Build are
 * given records of functions (to read a file, to stat, to run), and
 * Graph a function to stat, which the tests replace.
 *
 * Where it stands: ix is built by it, with a mkfile in each directory
 * (the top Makefile's "ix built by ix"), and the recipes are run by
 * the shell that $MKSHELL names. Two of its ideas come back in the
 * shell. A value is a list of words that is expanded (rc's Word has
 * the same name, with another rule for gluing). A command is a process
 * that is forked and waited for (rc's Process, and the kernel's side of
 * fork and wait).
 *
 * cs-history:
 * Stuart Feldman wrote make at Bell Labs in 1976. The story he tells
 * is of a colleague who lost a morning debugging a program that was
 * correct: the fix was in the source, but the object had not been
 * compiled again. Before make, a project had a shell script that
 * compiled everything, or a person who remembered what to compile.
 * Feldman's idea is the description file: you say once what depends on
 * what, and a program compares the dates. make is also the origin of
 * the tab that must start a recipe's line. Feldman has said he
 * regretted it but could not change it, because make already had a
 * dozen users.
 *
 * why-win:
 * Why dates? The system keeps a file's modification time anyway, it
 * costs one stat to read, and it needs no database beside the files.
 * If you remove make, the tree is still consistent; if you copy the
 * tree, the build goes on. Dates are wrong in ways everyone has met (a
 * clock set back, a checkout that touches every file, an option changed
 * on the command line that no file records), and each later build tool
 * is an answer to one of them. Outofdate has the rule, its corner
 * cases, and -H, which answers by content.
 *
 * evolution:
 * From make to mk. Andrew Hume wrote mk at Bell Labs (his paper is
 * of 1987), and Plan 9 took it as its only build tool. What mk
 * changed:
 * - The whole recipe goes to one shell, where make runs a shell for
 *   each line (Recipe).
 * - A variable of the mkfile is a variable of the recipe's
 *   environment, with no second syntax.
 * - A pattern rule uses %, where make had rules by suffix (Pattern).
 * - A rule can have attributes (:V: for a target that is not a file,
 *   where make needs .PHONY).
 * - Recipes run in parallel from the start ($NPROC, Build).
 * - There are no built-in rules; a mkfile includes the few it wants
 *   (Mkfile's <file).
 * - The graph is built whole before the first recipe runs (Graph), so
 *   a missing rule or a cycle is reported at once and not an hour into
 *   the build.
 * GNU make (1988) grew the other way, by adding things: functions,
 * conditionals, and pattern rules too.
 *
 * modern:
 * Ninja (2012, for Chrome's build) keeps make's dates and removes
 * the language: its files are written by another program, not by a
 * person, and it remembers each command line to rebuild when one
 * changes. Shake (2012) and Bazel (2015) decide by the content of
 * the inputs and not by their dates. Shake's rules may ask for a
 * dependency while they run, and Bazel runs each command in a
 * sandbox, where a dependency that is not declared is a file not
 * found. "Build Systems a la Carte" (2018) sorts them all by two
 * choices: in what order to build, and how to know that something must
 * be built. Here these are Build and Outofdate.
 *
 * The command line's usage and options are in [help] in CLI.ml, which
 * is what mini-mk -h prints (-h and --help are not mk's). -i is
 * accepted, but missing intermediates are always made here (Build, and
 * the plan's decision 5). For -H, see Outofdate; for var=value, see
 * Mkfile.
 *
 * With no target, mk makes the targets of the first rule that is not
 * :R: and has no % or &. $MKFLAGS is set to the options and
 * assignments, and $MKARGS to the targets. $NPROC (default 1) is how
 * many recipes run at once, and $NREP (default 1) is how often a
 * metarule may repeat on a path (Graph).
 *
 * References: Andrew Hume, "Mk: a Successor to Make" (USENIX, 1987),
 * which is short and the one to read first, and, with Bob Flandrena,
 * "Maintaining Files on Plan 9 with Mk", the tutorial; Stuart
 * Feldman, "Make -- A Program for Maintaining Computer Programs"
 * (Software: Practice and Experience, 1979); Andrey Mokhov, Neil
 * Mitchell and Simon Peyton Jones, "Build Systems a la Carte" (ICFP
 * 2018); mk(1); principia's builders/mk (main.c) and its book, and
 * xix's builder (omk). *)

type caps =
  < Recipe.caps; Cap.env; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr;
    Cap.clock >

(* [main caps argv] runs mk and returns the exit status: 0, or 1 after
 * an error. *)
val main : < caps; .. > -> string array -> int
