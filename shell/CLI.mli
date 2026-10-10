(* mini-rc: Plan 9's shell, rc. A line typed is read, made a tree,
 * and the tree is walked: words expanded to lists of strings,
 * programs found, forked and waited for.
 *
 *     characters                            the modules, a line's way
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
 * The shell, from 1965 to rc. The word and the idea are Louis
 * Pouzin's: on CTSS his RUNCOM ran commands from a file, and for
 * Multics he described the "shell", a program like any other that
 * reads commands and runs them, which could then be replaced. Ken
 * Thompson's shell for the first Unix (1971) is that program: a
 * command a line, < and >, and from 1973 the pipe; its if and goto
 * were programs. Steve Bourne's (the seventh edition, 1979) made it
 * a programming language: variables, for, case, while, functions
 * later, here documents, and `cmd`; every sh since is a superset of
 * it. Bill Joy's csh at Berkeley (1978) was for the person typing:
 * history, aliases, job control, ~. David Korn's ksh (1983) put both
 * in one. Tom Duff's rc (1989, for the tenth edition and Plan 9)
 * went the other way and removed: one kind of quote, a value that is
 * a list and is never scanned again (Word), a grammar yacc accepts
 * (Parser), and no job control, history or line editing, which on
 * Plan 9 are the window's (rio's text) and not each program's.
 *
 * others:
 * Byron Rakitzis rewrote rc for Unix (1991), with a few changes (an
 * else, where Duff has if not): the rc most Linux distributions
 * package. Its sources became es (Paul Haahr and Rakitzis, 1993), an
 * rc with closures, where pipes and redirections are functions a
 * user may redefine. Here it is Duff's rc, as plan9port and 9base
 * run it on Unix: the corpus is compared with 9base's.
 *
 * The command line: its usage, flags and a few examples are [help] in
 * CLI.ml, what mini-rc -h prints (-h and --help, not rc's flags).
 *
 * rc does not start in C: it runs a script, rcmain, which reads the
 * profile if asked, then the -c command, the file, or the terminal
 * (plan9port's rcmain, embedded here as it is in 9base; -m reads
 * another):
 *
 *     mini-rc script a b     *=(script a b); . rcmain -> . $*
 *     mini-rc -c 'cmd'       cflag=cmd; . rcmain -> eval $cflag
 *     mini-rc                . rcmain -> . -i /dev/stdin, with a prompt
 *                           if the input is a terminal, or with -i
 *
 * The environment is read first (functions included), then the flags
 * are set as variables flag reads, and $status is rc's exit code:
 * "" 0, a number that number, anything else 1.
 *
 * plan9-is-cleaner:
 * $status is a string because a Plan 9 process ends with one: exits
 * takes a message, empty for success, where Unix's exit takes a
 * number from 0 to 255 that each program gives its own meanings to.
 * The line above is that string made a number again, for a Unix
 * parent.
 *
 * References: Tom Duff, "Rc -- The Plan 9 Shell" (1990, in the Plan 9
 * manual's second volume): the paper to read first, short, and the
 * source of the quotations in this directory. rc(1). S. R. Bourne,
 * "The UNIX Shell" (Bell System Technical Journal, 1978). Louis
 * Pouzin, "The Origin of the Shell" (multicians.org, 2000). Paul
 * Haahr and Byron Rakitzis, "Es: A shell with higher-order functions"
 * (USENIX Winter 1993). principia's shells/rc. *)

type caps = < Eval.caps; Cap.argv; Cap.exit; Cap.stdout >

val main : < caps; .. > -> string array -> int
