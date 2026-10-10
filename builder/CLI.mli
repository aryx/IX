(* mini-mk: Plan 9's mk. A mkfile says what each file is made from
 * and by which commands; mk finds what is older than what it is made
 * from, and runs those commands and no others, in an order that
 * respects the dependencies, several at a time.
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
 * walk: a file's date against the dates of what it is made from.
 *
 *     mkfile, var=value                 the modules, a build's way
 *        | Mkfile     read once, evaluated as read: variables, rules
 *        |-- Word     a line's text to a list of words, $X expanded
 *        |-- Pattern  a rule's target: literal, %, &, a regexp
 *     rules
 *        | Graph      from a target, the rules that apply, down to
 *        |            the files that only exist
 *     nodes and arcs
 *        | Build      the walk: what is ready and out of date gets a
 *        |            job; again after each job ends
 *        |-- Outofdate  a node against a prerequisite: the dates
 *        |-- Archive    the date of lib.a(member)
 *        '-- Recipe     a job's variables, the shell forked, waited for
 *
 * Only this module and Recipe touch the system; Mkfile, Graph and
 * Build are given records of functions (to read a file, to stat, to
 * run), which the tests replace.
 *
 * Where it stands: ix is built by it, a mkfile in each directory
 * (the top Makefile's "ix built by ix"), the recipes run by the
 * shell $MKSHELL names; and two of its ideas are met again in the
 * shell: a value is a list of words, expanded (rc's Word, the same
 * name, with another rule for gluing), and a command is a process
 * forked and waited for (rc's Process, and the kernel's side of
 * fork and wait).
 *
 * cs-history:
 * Make is Stuart Feldman's, at Bell Labs in 1976. The story he
 * tells is of a colleague who lost a morning debugging a program
 * that was correct: the fix was in the source, and the object had
 * not been compiled again. Before make a project had a
 * shell script that compiled everything, or a person who remembered
 * what to compile. Feldman's idea is the description file: say what
 * depends on what, once, and let a program compare the dates. It is
 * also the origin of the tab that must start a recipe's line, which
 * he has said he regretted and could not change, make having
 * already a dozen users.
 *
 * why-win:
 * Why dates. A file's modification time is kept by the system
 * anyway, costs one stat to read, and needs no database beside the
 * files: remove make and the tree is still consistent, copy the
 * tree and the build goes on. It is wrong in ways everyone has met
 * (a clock set back, a checkout that touches every file, an option
 * changed on the command line that no file records), and each
 * later build tool is an answer to one of them. Outofdate has the
 * rule, its corner cases, and -H, the answer by content.
 *
 * evolution:
 * From make to mk. Andrew Hume wrote mk at Bell Labs (his paper is
 * of 1987), and Plan 9 took it as its only build tool. What
 * it changed: the whole recipe goes to one shell, where make runs a
 * shell a line (Recipe); a variable of the mkfile is a variable of
 * the recipe's environment, with no second syntax; a pattern rule
 * with % where make had rules by suffix (Pattern); attributes on a
 * rule (:V: for a target that is no file, where make needs .PHONY);
 * recipes in parallel from the start ($NPROC, Build); no built-in
 * rules, a mkfile including the few it wants (Mkfile's <file); and
 * the graph built whole before the first recipe runs (Graph), so a
 * missing rule or a cycle is said at once and not an hour into the
 * build. GNU make (1988) grew the other way, by adding: functions,
 * conditionals, the pattern rules too.
 *
 * modern:
 * Ninja (2012, for Chrome's build) keeps make's dates and removes
 * the language: its files are written by another program, not by a
 * person, and it remembers each command line to rebuild when one
 * changes. Shake (2012) and Bazel (2015) decide by the content of
 * the inputs and not their dates; Shake's rules may ask for a
 * dependency while they run, and Bazel runs each command in a
 * sandbox, where a dependency not declared is a file not found.
 * "Build Systems a la Carte" (2018) sorts them all by two choices,
 * in what order to build and how to know that something must be:
 * Build and Outofdate here.
 *
 * The command line: its usage and options are [help] in CLI.ml, what
 * mini-mk -h prints (-h and --help, not mk's). -i: missing intermediates
 * are always made here (Build, and the plan's decision 5); -H: see
 * Outofdate; var=value: see Mkfile.
 *
 * With no target, the targets of the first rule without % or & are
 * made. $MKFLAGS is set to the options and assignments, $MKARGS to the
 * targets; $NPROC (default 1) is how many recipes run at once, $NREP
 * (default 1) how often a metarule may repeat on a path (Graph).
 *
 * References: Andrew Hume, "Mk: a Successor to Make" (USENIX,
 * 1987), short, to read first, and with Bob Flandrena,
 * "Maintaining Files on Plan 9 with Mk", the tutorial; Stuart
 * Feldman, "Make -- A Program for Maintaining Computer Programs"
 * (Software: Practice and Experience, 1979); Andrey Mokhov, Neil
 * Mitchell and Simon Peyton Jones, "Build Systems a la Carte" (ICFP
 * 2018); mk(1); principia's builders/mk (main.c) and its book,
 * xix's builder (omk). *)

type caps = < Recipe.caps; Cap.env; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* [main caps argv]: the exit status: 0, or 1 after an error *)
val main : < caps; .. > -> string array -> int
