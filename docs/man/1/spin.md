\title{spin}{1}{processes}

# NAME
spin – do several cores give several times the work?

# SYNOPSIS
**spin**
[ *n* [ *kind* ] ]

# DESCRIPTION
*Spin* starts *n* processes (1 to 64; 1 when not said), each doing
the same work at once, waits for them all, and writes the time they
took. Set beside `spin 1`'s: with cores that do not wait for each
other in that work, `spin 4` takes as long; with one thing that all
share, four times as long. The *kind* of work says what may be
shared:

`ints`
:    A loop on integers: nothing shared. What is done with no *kind*.

`mem`
:    16 MB walked six times, read and written: the machine's memory.

`alloc`
:    Small blocks made and dropped: the program's collector, and the
     memory.

`sys`
:    The time asked of the kernel, over and over: the kernel.

# EXAMPLES
```
% spin 1 mem
spin 1 mem: 0.42 s
% spin 4 mem
spin 4 mem: 0.47 s
```

# DIFFERENCES
Plan 9's *spin*(1) is another program: the SPIN model checker, of
Gerard Holzmann's. This one is ix's, written when mini-9pi first ran
on the Pi 2's four cores.

# SEE ALSO
\man{time}{1}, \man{stats}{1}

# DIAGNOSTICS
A wrong *n* or *kind* writes the usage, with the four kinds.
