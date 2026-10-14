\title{seq}{1}{calc}

# NAME
seq – numbers in a row

# SYNOPSIS
**seq**
[ **-w** ]
[ *first* [ *incr* ] ]
*last*

# DESCRIPTION
*Seq* writes the numbers from *first* (1) to *last*, by *incr* (1),
which may go down, one a line, as `%g` writes them: for a loop of rc,
which has no arithmetic.

**-w**
:    All as wide, zeros before (not when the numbers go down).

# EXAMPLES
```
seq -w 8 10                 08 09 10
seq 1 .5 2                  1 1.5 2
for(i in `{seq 1 10}) echo $i
```

# DIFFERENCES
No **-f** *format*, though the usage names it: Plan 9's prints each
number by a format given on the command line.

# SEE ALSO
\man{rc}{1}, \man{hoc}{1}; *seq*(1)

# DIAGNOSTICS
An increment of 0 is said, and the status is `zero increment`.
