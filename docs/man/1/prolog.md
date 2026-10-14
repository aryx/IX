\title{prolog}{1}{languages}

# NAME
prolog – the Prolog language

# SYNOPSIS
**prolog**
[ **-g** *goal* ] ...
[ **-wam** ]
[ **-S** ]
[ **-trace** ]
[ **-s** ]
[ *file*`.pl` ... ]

# DESCRIPTION
*Prolog* is Prolog in Edinburgh's syntax, the standard's core. The
*files* are consulted in order: each clause is added, each
directive `:- Goal` run. Then each **-g** *goal* is run once. With
no **-g**, a prompt, `?-`: a goal may take several lines, to its
final dot, and its answer is the variables' values, or `true`, or
`false`. When there may be another answer, ` ?` waits: `;` and
Enter asks for it, Enter alone stops.

**-g** *goal*
:    *Goal* is run once.

**-trace**
:    Each call's ports are printed: Call, Exit, Redo, Fail.

**-wam**
:    The clauses are compiled to the instructions of Warren's
     abstract machine and run by it. The answers are the same; the
     steps counted are the calls, and there is no **-trace**.

**-S**
:    The machine's instructions for the files' predicates, and
     nothing run.

**-s**
:    At the end, the machine's steps.

**-h**
:    How, by examples.

# EXAMPLES
```
prolog -g 'X is 6 * 7, write(X), nl'
prolog -g 'append(X, Y, [a,b]), write(X-Y), nl, fail'
prolog queens.pl -g 'queens(8, Qs), print(Qs), nl'
prolog -trace family.pl -g 'grandparent(tom, X)'
```

# SEE ALSO
\man{datalog}{1}, \man{scheme}{1}

# DIAGNOSTICS
A goal of **-g** that fails or throws is said, and the status is 1.

# BUGS
Integers only. No modules, no strings (a text between double quotes
is the list of its codes), no occurs check
(`unify_with_occurs_check` does it).
