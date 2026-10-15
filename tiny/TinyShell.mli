(* A tiny shell, in one file, with pipes, redirections, variables and
 * basic control flow. mini-rc (shell/) is a faithful copy of rc; this
 * shell is what remains when compatibility is dropped. It was written
 * after mini-rc, using what mini-rc taught. The language is a cut-down
 * version of rc's:
 *
 *     ls -l *.c | wc -l >count         words, globs, a pipe, redirections
 *     x=(a b c); echo $x $#x $x.o      lists, the only value; a.o b.o c.o
 *     for(f in *.c) cc -c $f           if(cmd) cmd   while(cmd) cmd
 *     test -f x && echo y || echo n    ! cmd   { cmds }   @{ cmds }
 *     fn f { echo $1 }; f a            functions, $* $1 $2 ...
 *     y=`{date}; sleep 1 &; wait       command output as words; &
 *     cc -c x.c >[2]errs >[2=1]        other fds
 *     ~ $x *.c && echo matched         matching: ~ subject pattern ...
 *
 * How a line is processed: its characters are split into tokens, the
 * tokens are parsed into a tree ([cmd], by recursive descent), and the
 * tree is walked ([run]). Along the way each word is turned into a
 * list of strings ([word], then [glob]). For example, with x=(a b),
 * the line echo $x.o | wc >n becomes the tree
 *
 *     Pipe (Simple [echo; $x then .o], Simple [wc] with 1 opened on n)
 *
 * and walking it creates three processes, while the shell itself does
 * everything that is not running a program:
 *
 *     the shell          makes a pipe, then forks
 *      |-- a child       its 1 is the pipe; it walks the first Simple:
 *      |    |            $x joined to .o gives a.o b.o, nothing to glob
 *      |    '-- echo     forked and exec'ed; the child waits for it and
 *      |                 exits with echo's status
 *      |                 the shell's own 0 is now the pipe (the old 0
 *      |                 is saved); it walks the second Simple: 1 is
 *      |                 now n (the old 1 is saved)
 *      '-- wc            forked and exec'ed; the shell waits for it,
 *                        restores 1, then 0, waits for the child, and
 *                        sets $status to the statuses joined by a bar
 *
 * What is kept from rc, and why it is the core:
 *
 * - {b Every value is a list of strings.} $x is never split again, so
 *   there is no need to quote $x, no "$@", and $* is exactly the
 *   arguments as they were given. The only quote is '...' (with ''
 *   inside standing for a quote).
 * - {b Adjacent words are joined, distributing over lists}: $x.o is
 *   a.o b.o c.o, and two lists of the same length are joined pair by
 *   pair. rc does this with a "free caret" that its lexer inserts.
 *   Here a word is simply its pieces with nothing between them, and ^
 *   is only a way to write two pieces with nothing between them.
 * - {b Only literal text is globbed}: a * coming from a variable or a
 *   quote stays a *. The trick is that such characters are escaped (a
 *   \000 is put before them) while the word is built, so the matcher
 *   can tell them apart; the escapes are removed once the files are
 *   found.
 * - {b Redirections are done by the shell, around the command, and
 *   undone afterwards} (the fds are saved, then restored), so a
 *   function or a brace block sees them just as a program does.
 * - {b The syntax tree is walked directly}: a child forked for a stage
 *   of a pipe or for a subshell walks its subtree and then exits; the
 *   last stage of a pipe runs in the shell itself.
 * - {b $status is a string}: "" for success, otherwise the exit code
 *   or the signal; for a pipe it is the statuses of its stages joined
 *   by |.
 *
 * What is dropped, each of which is a few lines in mini-rc, and none of
 * which is needed by the recipes in xix's mkfiles (the test for this
 * shell, see below): switch and if not, here documents, joining a list
 * into one word, subscripts, `sep{} and <{}, `{} inside a word, eval
 * and ., all builtins except cd, exit, shift, wait and ~, functions in
 * the environment, a $path separate from $PATH, -x, rcmain, signals
 * other than an interrupt at the prompt, and $prompt. These make good
 * exercises, roughly in that order.
 *
 * The tests: test.sh runs scripts written in this subset both through
 * this shell and through 9base's rc, which must print the same thing.
 * Also, mini-mk builds all of xix using this shell (as MKSHELL, through
 * a link named rc, so that mini-mk exports lists the way rc expects
 * them, joined by \001).
 *
 * Usage: see [help] below, which shows the language by example; it is
 * what tiny-shell -h prints.
 *
 * Where it stands: the shell relies on five kernel calls, fork, exec,
 * wait, pipe and dup (from CapUnix and Unix here; the loops around
 * them are in Procs, which is shared with mini-mk and
 * TinyBuildSystem). TinyKernel has the same five calls and a shell in
 * C built on them (its user/sh.c), and mini-9pi's calls are what
 * mini-rc's Process uses. Above this shell is mini-mk, which hands it
 * each recipe. The history of shells, from Pouzin's RUNCOM to rc, is
 * told once, in mini-rc's CLI.mli.
 *
 * design:
 * Making every value a list is what removes the need for quoting. In
 * the Bourne shell a variable is a single string, and $x is split
 * again at blanks and globbed every time it is used. So a file name
 * containing a space becomes two arguments unless every use is
 * surrounded by double quotes, and the arguments need a special form
 * to stay intact ("$@", the dollar and at sign, quoted). Most of the
 * rules a shell programmer learns are workarounds for that second
 * scan. Duff's rc splits the text once, when it is read, and keeps the
 * pieces, so there is nothing to protect later.
 *
 * others:
 * xv6's sh.c is the other shell written to be read: about 500 lines of
 * C. It also builds a tree (one struct per kind of command: exec,
 * redirection, pipe, list, background), walked by a single function,
 * runcmd, which never returns: every node runs in a child. It has no
 * variables, no control flow and no globbing. This shell instead walks
 * the tree itself and forks only for a program, the first stages of a
 * pipe, & and @. That is why a cd or an assignment inside braces is
 * still visible after them.
 *
 * wib:
 * A pipe stage that is a single program costs two processes: the child
 * that walks its subtree, and the program that this child forks and
 * waits for. A more careful shell would exec the program directly in
 * the child when it is the last thing the child does. That saves one
 * fork per stage, at the cost of checking what comes next in every
 * case of [run]. This is not done.
 *
 * On two systems: this file is compiled by OCaml for the host and by
 * tiny-ml for tiny-machine, where it is tiny-kernel's rc. It uses only
 * the pure functions of the standard library (tiny-ml provides them in
 * TinyLibStd) and, for everything related to the system,
 * TinyLibSystem, which has one implementation file per side. That is
 * why there are no labels, no modules of its own, and an exception
 * Exits where Exit from the library would otherwise be used.
 *
 * References: Tom Duff, "Rc -- The Plan 9 Shell" (1990), for the
 * language and for the principle that the lists protect: input "is
 * never scanned more than once"; D. M. Ritchie and K. Thompson, "The
 * UNIX Time-Sharing System" (CACM, 1974), for fork and exec as two
 * separate calls, between which the child sets up its own file
 * descriptors, and for the shell as an ordinary program. *)

(* the commands of a text, each run once it is read: the lexer, the
 * parser and [run] at work, without the command line around them *)
val source :
  < Cap.fork; Cap.exec; Cap.wait; Cap.chdir; Cap.open_in; Cap.open_out; Cap.stdin; Cap.stderr > -> string -> unit

(* the program: its arguments (-h: the language by example) to its exit status *)
val main : Cap.all_caps -> int
