\title{free}{1}{system}

# NAME
free – the memory, and who has it

# SYNOPSIS
**free**

# DESCRIPTION
*Free* writes the board's memory as the kernel divides it, its
total, then what the kernel, the processes and the swap have of it,
in megabytes: all, taken, left. Then a line a process: its number,
the memory it holds (the pages it has touched), what it asked for
(its segments' sizes, as \man{ps}{1} says), and its name.

A page shared by several processes, a program's text, is counted
for each.

The name is Unix's; on Plan 9 it is `cat /dev/swap` and
\man{ps}{1}.

# EXAMPLES
```
free
```

# FILES
`/dev/swap`, `/proc/*/status`, `/proc/*/segment`

# SEE ALSO
\man{ps}{1}

# DIAGNOSTICS
A `/dev/swap` that cannot be read is said: it is mini-9pi's, and on
another system there is none.
