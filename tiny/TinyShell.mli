(* A tiny shell, in one file, with pipes, redirections, variables and
 * basic control flow. The language is a cut-down version of rc's:
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
 * archi:
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
 * twin:
 * mini-rc (shell/) is a faithful copy of rc; this shell is what remains
 * when compatibility is dropped.
 *
 * kept:
 * It keeps rc's core, and each item below says why it is the core:
 * - {b Every value is a list of strings.} $x is never split again, so
 *   there is no need to quote $x, no "$@", and $* is exactly the
 *   arguments as they were given. The only quote is '...' (with ''
 *   inside standing for a quote).
 * - {b Adjacent words are joined, distributing over lists}: $x.o is
 *   a.o b.o c.o, and two lists of the same length are joined pair by
 *   pair. rc does this with a "free caret" that its lexer inserts.
 *   Here a word is simply its pieces with nothing between them, and ^
 *   is only a way to write two pieces with nothing between them. A
 *   `{cmd} is joined only by an explicit ^ (lib/^`{basename $f}): it
 *   makes the join visible where a reader could otherwise take the
 *   word and the command for two words.
 * - {b Only literal text is globbed}: a * coming from a variable or a
 *   quote stays a *. The trick is that such characters are escaped (a
 *   \000 is put before them) while the word is built, so the matcher
 *   can tell them apart; the escapes are removed once the files are
 *   found.
 * - {b Redirections are done by the shell, around the command, and
 *   undone afterwards} (the fds are saved, then restored), so a
 *   function or a brace block sees them just as a program does.
 * - {b The syntax tree is walked directly}: a child forked for a stage
 *   of a pipe or for a subshell walks its subtree and then exits, or,
 *   when the subtree is a program, execs it in place; the last stage
 *   of a pipe runs in the shell itself.
 * - {b $status is a string}: it is "" for success, and otherwise the
 *   exit code or the signal. For a pipe it is the same as in rc: a|b|c
 *   is read as (a|b)|c, and the status of a|b counts as the exit code
 *   that a child running it would have, which is its first number. So
 *   the statuses 1, 2 and 3 give 1|3.
 *
 * A pipe stage that is a single program costs one process: the child
 * forked for it execs the program in place, as it has nothing left to
 * do, instead of forking it and waiting for it. The shell forks every
 * stage itself, from the list of stages, rather than a child for the
 * pipe on the left of the last |. So a|b|c|d is four processes rather
 * than seven. tiny-kernel has room for eight processes, so with sh and
 * rc running it can run six stages. Past that, fork fails and the shell
 * says "try again", as rc does.
 *
 * dropped:
 * It drops the following features. Each takes a few lines in mini-rc,
 * and none is needed by the recipes in xix's mkfiles, which are the
 * test for this shell: switch and if not, here documents, joining a
 * list into one word, subscripts, `sep{} and <{}, `{} inside a word,
 * eval and ., all builtins except cd, exit, shift, wait and ~,
 * functions in the environment, a $path separate from $PATH, -x,
 * rcmain, signals other than an interrupt at the prompt, and $prompt.
 *
 * context:
 * The shell relies on five kernel calls, fork, exec, wait, pipe and dup,
 * all through TinyLibSystem. On the host they go to Unix, and the loops
 * around them are in lib_core's Procs, shared with mini-mk; on
 * tiny-kernel they are the kernel's own calls.
 * TinyKernel has the same five calls and a shell in C built on them
 * (its user/sh.c), and mini-9pi's calls are what mini-rc's Process
 * uses. Above this shell is mini-mk, which hands it each recipe. The
 * history of shells, from Pouzin's RUNCOM to rc, is told once, in
 * mini-rc's CLI.mli.
 *
 * The same file is tiny-kernel's rc and the host's tiny-shell. It uses
 * only the pure functions of the standard library and, for
 * everything related to the system, TinyLibSystem, which has one
 * implementation file per side.
 *
 * exercises:
 * What is dropped above makes good exercises, roughly in that order.
 * Here is one more, which rc does not have: make > a transaction. The
 * output is written to a new file beside the target and renamed over it
 * only when the command succeeds (TSys.rename, as tiny-vcs writes its
 * head). Then sort f > f sorts f instead of emptying it (> truncates f
 * before sort reads it, which is why sponge exists), and a command that
 * fails leaves the old file, not half a new one that looks whole. The
 * price is that the output appears only at the end (no tail -f on a
 * log), that a hard link to the file keeps the old one, and that
 * devices, >> and >[2] must be left as they are. There are two more, in
 * the direction that Tcl and es took. First, a block
 * as a value (its text), with if, while, for and fn as builtins over
 * blocks; then a function is just a variable (fn#f), and eval, whatis,
 * switch and functions in the environment come almost for free.
 * Second, $status as a list: a|b|c would give (1 '' 3) rather than
 * rc's string 1|3.
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
 * references:
 *  - Tom Duff, "Rc -- The Plan 9 Shell" (1990): the language, and the
 *    principle that the lists protect: input "is never scanned more
 *    than once"
 *  - D. M. Ritchie and K. Thompson, "The UNIX Time-Sharing System"
 *    (CACM, 1974): fork and exec as two separate calls, between which
 *    the child sets up its own file descriptors, and the shell as an
 *    ordinary program
 *  - principia's shells/rc, the C code of rc, which mini-rc follows and
 *    this file knows only through mini-rc
 *)

(* What running a command needs. The program also needs a terminal
 * (stdin, the signal of an interrupt) and the environment. *)
type caps =
  < Cap.forkew; Cap.chdir; Cap.open_in; Cap.open_out; Cap.pipe;
    Cap.readdir; Cap.stdout; Cap.stderr; Cap.exit >

(* Runs each command of a text as soon as it is read, without the
 * command line around. *)
val source : < caps; .. > -> string -> unit

(* The program. -h prints the language by example, and -debug prints
 * the tree of each command. *)
val main :
  < caps; Cap.stdin; Cap.signal; Cap.env; .. > -> string array -> Exit.t
