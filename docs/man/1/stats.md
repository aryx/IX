\title{stats}{1}{apps}

# NAME
stats – how busy each core is, as a graph

# SYNOPSIS
**stats**

# DESCRIPTION
*Stats* draws, in its window, a strip for each core of the machine:
how busy the core was, the newest at the right, the strip moving left
five times a second, with its percent of now. Busy is running a
process, or in the kernel, or waiting for the kernel's lock. It reads
`/dev/sysstat`, a line a core, whose ninth number is the percent of
its time the core had nothing to run.

The right button's menu has `exit`.

# EXAMPLES
```
stats &
spin 4 mem
```

# FILES
`/dev/sysstat`

# DIFFERENCES
One graph of Plan 9's many, the cores' load: not the memory, the
network, the interrupts nor the system calls (mini-9pi's
`/dev/sysstat` says 0 for most), nor another machine's. No option.

# SEE ALSO
\man{ps}{1}, \man{free}{1}, \man{spin}{1}, \man{rio}{1}; Plan 9's
*stats*(8)

# DIAGNOSTICS
An argument writes the usage.
