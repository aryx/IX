\title{dc}{1}{calc}

# NAME
dc – the desk calculator, on a stack

# SYNOPSIS
**dc**
[ *file* ]

# DESCRIPTION
*Dc* runs the commands of *file*, then of the standard input: numbers
of any size pushed on a stack, the operators after their operands
(`+ - * / % ^ v`), `p` and `f` to print, `k` the scale, `i` and `o`
the bases, registers (`s`*r*, `l`*r*), macros in brackets run by `x`,
and `!` for a command of rc. *dc*(1) of Plan 9 tells them all.

**-h**
:    How, by examples.

# EXAMPLES
```
echo '2 3 + p' | dc                    5
echo '20k 2 v p' | dc                  1.41421356237309504880
```

# DIFFERENCES
No limits on memory, and no `Y`, which printed them. A 0 made by `z`,
`Z` or `X` keeps its extra digit only until it is computed with.

# SEE ALSO
\man{bc}{1}, \man{hoc}{1}; *dc*(1)
