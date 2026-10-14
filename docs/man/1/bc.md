\title{bc}{1}{calc}

# NAME
bc – a calculator of numbers of any size, in C's notation

# SYNOPSIS
**bc**
[ **-cdls** ]
[ *file* ... ]

# DESCRIPTION
*Bc* runs the statements of the *files*, then of the standard input,
each when read: expressions printed, variables, arrays, `if`, `while`,
`for`, functions (`define`), and `scale`, `ibase`, `obase`. It
compiles each to \man{dc}{1}'s commands, which do the arithmetic.
*bc*(1) of Plan 9 tells the language.

**-l**
:    The library first: `s c a l e j`, sine to Bessel's function, and a
     scale of 50.

**-c**
:    The commands for *dc* printed, not run.

**-s**
:    Silent: an expression's value is not printed.

**-d**
:    Taken, and nothing done.

# EXAMPLES
```
echo '2^100' | bc
echo 'scale=20; sqrt(2)' | bc
echo 'a(1)*4' | bc -l
```

# DIFFERENCES
*Dc* is not another program at the end of a pipe but its machine in
this one, and the library is in the program, not `/sys/lib/bclib`.

# SEE ALSO
\man{dc}{1}, \man{hoc}{1}; *bc*(1)
