(* A tiny shell, in one file: pipes, redirections, variables and basic
 * control flow. mini-rc (shell/) is rc, faithfully; this is what is left
 * when compatibility is dropped, written after it, from what it taught.
 * The language is rc's, cut down:
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
 * A line's way: its characters to tokens, the tokens to a tree ([cmd],
 * by recursive descent), and the tree walked ([run]), a word becoming
 * a list of strings on the way ([word], then [glob]). With x=(a b),
 * the line echo $x.o | wc >n is the tree
 *
 *     Pipe (Simple [echo; $x then .o], Simple [wc] with 1 opened on n)
 *
 * and walking it makes three processes, the shell doing in itself all
 * that is not a program:
 *
 *     the shell          a pipe made, then a fork
 *      |-- a child       its 1 is the pipe; it walks the first Simple:
 *      |    |            $x joined to .o is a.o b.o, nothing to glob
 *      |    '-- echo     forked and exec'ed; the child waits, and exits
 *      |                 with echo's status
 *      |                 its own 0 is now the pipe, the old one copied
 *      |                 away; it walks the second Simple: 1 is n, the
 *      |                 old one copied away
 *      '-- wc            forked and exec'ed; the shell waits; 1 is put
 *                        back, then 0; the child is waited for, and
 *                        $status is its status, a bar, wc's
 *
 * What is kept from rc, and why it is the core:
 *
 * - {b Every value is a list of strings.} $x is never split again, so
 *   there is no quoting of $x, no "$@", and $* is the arguments as they
 *   were. The only quote is '...' ('' inside is a quote).
 * - {b Words next to each other are joined, distributing over lists}:
 *   $x.o is a.o b.o c.o, and two lists of the same length join
 *   pairwise. rc does this with a "free caret" that its lexer inserts;
 *   here a word simply is the pieces with nothing between them, and ^
 *   is only a way to write two pieces with nothing between.
 * - {b Only the literal text globs}: a * from a variable or a quote is
 *   a *. The trick: such characters are escaped (a \000 before them)
 *   as the word is built, so the matcher sees which is which; the
 *   escapes go once the files are found.
 * - {b Redirections are done in the shell, around the command, and
 *   undone after} (the fds are copied away, then put back), so a
 *   function or a brace sees them as a program does.
 * - {b The syntax tree is walked}: a child forked for a pipe's stage
 *   or a subshell walks its subtree, and exits; the last stage of a
 *   pipe runs in the shell itself.
 * - {b $status is a string}: "" for success, the exit code, or the
 *   signal; a pipe's is its stages' joined by |.
 *
 * What is dropped, each a few lines of mini-rc, and none needed by the
 * recipes of xix's mkfiles (this shell's test, below): switch and if
 * not, here documents, a list joined into one word and subscripts,
 * `sep{} and <{}, `{} inside a word, eval and ., the builtins but cd
 * exit shift wait and ~, functions in the environment, a $path apart
 * from $PATH, -x, rcmain, signals but an interrupt at the prompt, and
 * $prompt. Exercises, roughly in that order.
 *
 * The tests: test.sh runs scripts of this subset through it and
 * through 9base's rc, which must print the same; and mini-mk builds
 * all of xix with it as its shell (MKSHELL, through a link named rc,
 * so that mini-mk exports lists the way rc wants them, joined by \001).
 *
 * Usage: [help] below, with the language by example, what tiny-shell -h
 * prints.
 *
 * Where it stands: under it are five calls of the kernel, fork, exec,
 * wait, pipe and dup (CapUnix and Unix here; Procs for the loops
 * around them, shared with mini-mk and TinyBuildSystem); TinyKernel
 * has the same five and a shell in C over them (its user/sh.c), and
 * mini-9pi's are what mini-rc's Process calls. Above it is mini-mk,
 * which hands it each recipe. The shell's history, from Pouzin's
 * RUNCOM to rc, is told once, in mini-rc's CLI.mli.
 *
 * design:
 * A value that is a list is what removes the quoting. In Bourne's
 * shell a variable is one string, and $x is cut again at blanks and
 * globbed each time it is used: so a file named with a space is two
 * arguments unless every use is written with double quotes around
 * it, and the arguments need a form of their own to stay themselves
 * (the dollar and at sign, quoted). Most of the rules a shell
 * programmer learns are ways around that second scan. Duff's rc cuts
 * once, when the text is read, and keeps the pieces: there is nothing
 * to protect later.
 *
 * others:
 * xv6's sh.c is the other shell written to be read: about 500 lines of
 * C, also a tree (a struct per kind of command: exec, redirection,
 * pipe, list, background) walked by one function, runcmd, which never
 * returns: every node is run in a child. It has no variable, no
 * control flow, no glob. Here the shell walks the tree itself and
 * forks only for a program, a pipe's first stages, & and @, which is
 * why a cd or an assignment inside braces is seen after them.
 *
 * wib:
 * A pipe's stage that is one program costs two processes, the child
 * that walks its subtree and the program that child forks and waits
 * for. A shell that cares execs the program in the child when it is
 * the last thing the child will do; one fork saved a stage, for a
 * test of what comes after in every case of [run]. Not done.
 *
 * References: Tom Duff, "Rc -- The Plan 9 Shell" (1990), for the
 * language, and for the principle the lists are there to keep: input
 * "is never scanned more than once"; D. M. Ritchie and K. Thompson,
 * "The UNIX Time-Sharing System" (CACM, 1974), for fork and exec as
 * two calls, between which a child sets up its own file descriptors,
 * and the shell as an ordinary program. *)

(* the commands of a text, each run once it is read: the lexer, the
 * parser and [run] at work, without the command line around them *)
val source :
  < Cap.fork; Cap.exec; Cap.wait; Cap.chdir; Cap.open_in; Cap.open_out; Cap.stdin; Cap.stderr > -> string -> unit

(* the program: its arguments (-h: the language by example) to its exit status *)
val main : Cap.all_caps -> int
