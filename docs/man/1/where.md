\title{where}{1}{devtools}

# NAME
where – a trace's addresses named

# SYNOPSIS
**where**
*program*
*address* ...

# DESCRIPTION
*Where* says, of each *address* of *program*, the function it is in,
the offset in it, and its file and line, from the program's own
symbol table and pc/line table (\man{ld}{1} **-g**). An address is
hexadecimal, `0x` before it or not; the words of a trace can be given
as they are (`lr=0x1698`), what is no address left out. The line is,
in a program of \man{ml}{1}, the first of the function's body; in an
assembler's program, the instruction's.

# EXAMPLES
```
where /bin/rio 103ee4 10a0e0
where hello lr=0x105c
```

# DIFFERENCES
Plan 9 has no such program: *src*(1) and *acid*(1) say a function's
file and line.

# SEE ALSO
\man{nm}{1}, \man{ld}{1}

# DIAGNOSTICS
An address in no function is `?`; a program without a symbol table
is said, its status `no table`.
