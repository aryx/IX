(* mini-rc is Plan 9's shell, rc. It reads a line typed, makes a tree
 * of it, and walks the tree: the words are expanded to lists of
 * strings, and the programs are found, forked and waited for.
 *
 *     characters                            the modules, in a line's way
 *        | Lexer     quotes, free carets, redirections with their fds
 *     tokens
 *        | Parser    by recursive descent, syn.y's grammar
 *     Ast.cmd  ----- Show_ast: the tree as rc's text again (whatis, -x,
 *        |           a function in the environment)
 *        | Eval      walks it
 *        |-- Word    $x, $#x, a^b, `{cmd}: a word to a list of strings
 *        |-- Glob    *.c to the file names
 *        |-- Env     variables and functions, and their export
 *        |-- Builtin cd, ., eval, exit...: what must be done in the shell
 *        '-- Process fork, exec, wait, pipe, dup: the rest
 *
 * evolution:
 * This is the story of the shell, from 1965 to rc. The word and the
 * idea are Louis Pouzin's. On CTSS his RUNCOM ran commands from a
 * file, and for Multics he described the "shell", a program like any
 * other that reads commands and runs them, and that could therefore be
 * replaced. Ken Thompson's shell for the first Unix (1971) is that
 * program: it ran one command a line, had < and >, and from 1973 the
 * pipe; its if and goto were separate programs. Steve Bourne's shell
 * (the seventh edition, 1979) made it a programming language, with
 * variables, for, case, while, functions later, here documents, and
 * `cmd`; every sh since is a superset of it. Bill Joy's csh at
 * Berkeley (1978) was made for the person typing, with history,
 * aliases, job control and ~. David Korn's ksh (1983) put both in
 * one. Tom Duff's rc (1989, for the tenth edition and Plan 9) went the
 * other way and removed things. It has one kind of quote, a value
 * that is a list and is never scanned again (Word), and a grammar
 * that yacc accepts (Parser). It has no job control, history or line
 * editing, because on Plan 9 those belong to the window (rio's text)
 * and not to each program.
 *
 * others:
 * Byron Rakitzis rewrote rc for Unix (1991), with a few changes (an
 * else, where Duff has if not); it is the rc that most Linux
 * distributions package. Its sources became es (Paul Haahr and
 * Rakitzis, 1993), an rc with closures, where pipes and redirections
 * are functions that a user may redefine. This directory follows
 * Duff's rc, as plan9port and 9base run it on Unix, and its test
 * corpus is compared with 9base's.
 *
 * The command line: its usage, its flags and a few examples are in
 * [help] in CLI.ml, which is what mini-rc -h prints (-h and --help
 * are not rc's flags).
 *
 * rc does not start in C. It runs a script, rcmain, which reads the
 * profile if asked, then runs the -c command, the file, or the
 * terminal. The rcmain is plan9port's, embedded here as it is in
 * 9base, and -m reads another one:
 *
 *     mini-rc script a b     *=(script a b); . rcmain -> . $*
 *     mini-rc -c 'cmd'       cflag=cmd; . rcmain -> eval $cflag
 *     mini-rc                . rcmain -> . -i /dev/stdin, with a prompt
 *                           if the input is a terminal, or with -i
 *
 * The environment is read first (functions included), then the flags
 * are set, as variables that the flag builtin reads. rc's exit code
 * comes from $status: "" gives 0, a number gives that number, and
 * anything else gives 1.
 *
 * plan9-is-cleaner:
 * $status is a string because a Plan 9 process ends with one: exits
 * takes a message, empty for success, where Unix's exit takes a
 * number from 0 to 255 that each program gives its own meanings to.
 * The rule above makes that string a number again, for a Unix parent.
 *
 * References: Tom Duff, "Rc -- The Plan 9 Shell" (1990, in the second
 * volume of the Plan 9 manual): it is the paper to read first, it is
 * short, and it is the source of the quotations in this directory.
 * rc(1). S. R. Bourne, "The UNIX Shell" (Bell System Technical
 * Journal, 1978). Louis Pouzin, "The Origin of the Shell"
 * (multicians.org, 2000). Paul Haahr and Byron Rakitzis, "Es: A shell
 * with higher-order functions" (USENIX Winter 1993). principia's
 * shells/rc. *)

type caps = < Eval.caps; Cap.argv; Cap.exit; Cap.stdout >

val main : < caps; .. > -> string array -> int
