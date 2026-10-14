\title{hoc}{1}{calc}

# NAME
hoc – a calculator with variables, loops and functions

# SYNOPSIS
**hoc**
[ **-e** *expression* ]
[ *file* ... ]

# DESCRIPTION
*Hoc* reads the *files* in order, or the standard input (`-`), a line
at a time, and runs each: an expression's value is printed, an
assignment's is not. Numbers are floating point. The language is
Kernighan and Pike's hoc6, as Plan 9's: variables, `if`, `while`,
`for`, `func` and `proc` with named parameters, `return`, `print`,
`read`, the functions `sin cos tan atan asin acos sinh cosh tanh exp
log log10 sqrt int abs` and
the constants `PI E GAMMA DEG PHI`. *hoc*(1) of Plan 9 tells it.

**-e** *expression*
:    The expression is run, and not the files.

**-h**
:    How, by examples.

# EXAMPLES
```
hoc -e '2^10 + sqrt(2)'
func fac(n) { if (n <= 0) return 1; return n * fac(n-1) }
fac(10)
```

# DIFFERENCES
No limit on a program's size or on the depth of its calls. A `return`
outside a function, before a token that starts no expression, is a
syntax error; `x %= 0` is an error. Plan 9's bug of a `return` alone
under an `if` or a `while` is not here.

# SEE ALSO
\man{bc}{1}, \man{dc}{1}, \man{awk}{1}; *hoc*(1)

# DIAGNOSTICS
An error is said with its line; at a terminal the input goes on after
it, in a file it stops there. The status is always 0.
