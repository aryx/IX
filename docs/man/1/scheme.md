\title{scheme}{1}{languages}

# NAME
scheme – the Scheme language, and How to Design Programs' Beginning
Student

# SYNOPSIS
**scheme**
[ **-student** ]
[ **-step** ]
[ **-secd** ]
[ **-e** *expression* ] ...
[ **-s** ]
[ *file*`.scm` ... ]

# DESCRIPTION
*Scheme* runs a small Scheme, R5RS's core, on a CESK machine. The
*files* are run in order, then each **-e**, in one machine: what one
defines, the next sees. Each form at the top is evaluated and its
value printed, as DrScheme does on Execute; a definition prints
nothing. With no **-e** and no *file*, what is typed is read, and an
expression is run when its last parenthesis closes.

**-e** *expression*
:    *Expression* is run.

**-student**
:    Values printed as Beginning Student prints them, as what makes
     them: `(list 1 2)`.

**-step**
:    Nothing is run: Beginning Student's stepper prints each step of
     the texts, the expression before and after it is rewritten.

**-secd**
:    The texts are run by Landin's SECD machine (1964: a stack, an
     environment, a control, a dump), with the same values and
     errors. With it, **-trace** prints the four registers before
     each step, and **-landin** makes every call save on the dump,
     as the first machine did.

**-s**
:    At the end, the machine's steps.

**-h**
:    How, by examples.

# EXAMPLES
```
scheme -e '(+ 1 2 3)'
scheme -e "(map (lambda (x) (* x x)) '(1 2 3))"
scheme -step -e '(define (sq x) (* x x)) (sq (+ 1 2))'
scheme queens.scm
```

# SEE ALSO
\man{drscheme}{1}, \man{prolog}{1}, \man{forth}{1}

# DIAGNOSTICS
An error is said with its line, the rest of that text is left, and
the status is 1.

# BUGS
An image is said and not drawn, and `(big-bang ...)` fails: there is
no window; \man{drscheme}{1} has one.
