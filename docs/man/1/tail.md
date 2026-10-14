\title{tail}{1}{text}

# NAME
tail – the end of a file

# SYNOPSIS
**tail**
[ **+**|\strong{-}\emph{number}[**lbc**][**rf**] ]
[ *file* ]

**tail**
[ **-fr** ]
[ **-n** *nlines* ]
[ **-c** *nbytes* ]
[ *file* ]

# DESCRIPTION
*Tail* writes the last 10 lines of *file*, or of the standard input.

\strong{-}\emph{number}, **-n** *number*
:    The last *number* lines.

\strong{+}\emph{number}
:    From line *number* to the end.

**c**, **-c** *number*; **b**
:    Bytes, not lines; blocks of 1024 bytes.

**-r**
:    The lines last first: all of them with no *number*.

**-f**
:    Then what is written to the file afterwards, looked for every 5
     seconds, until interrupted.

# EXAMPLES
```
tail -20 log
tail -f log
```

# DIFFERENCES
The file is read whole and its end cut from it, where Plan 9's tail
seeks to the end and reads back.

# SEE ALSO
\man{sed}{1}; *tail*(1)
