\title{stats}{1}{apps}

# NAME
stats – how busy the machine is: cores, memory, network, disk, as graphs

# SYNOPSIS
**stats** [**-cmed**]

# DESCRIPTION
*Stats* draws, in its window, a strip for each thing it shows, the
newest at the right, the strip moving left five times a second, with
its number of now. By default all that the machine has; **-c** the
cores, **-m** the memory, **-e** the ethernet, **-d** the disk.

A core's strip is how busy it was: running a process, or in the kernel,
or waiting for the kernel's lock (`/dev/sysstat`, a line a core, whose
ninth number is the percent of its time the core had nothing to run).
The memory's is the percent of the user's pages taken (`/dev/swap`). The
ethernet's is packets a second, in and out (`/net/ether0/stats`), and the
disk's bytes a second, read and written (the `io` line of
`/dev/sdM0/ctl`): those two on a scale of powers of ten, up to 10,000
packets and 10 MB, so that a little shows beside a lot.

The right button's menu has `exit`.

# EXAMPLES
```
stats &
spin 4 mem
```

# FILES
`/dev/sysstat`, `/dev/swap`, `/net/ether0/stats`, `/dev/sdM0/ctl`

# DIFFERENCES
Four graphs of Plan 9's many: not the interrupts nor the system calls
(mini-9pi's `/dev/sysstat` says 0 for most), nor another machine's. The
options' letters are not Plan 9's, whose load is **-l**; its *stats* has
no disk.

# SEE ALSO
\man{ps}{1}, \man{free}{1}, \man{spin}{1}, \man{rio}{1}; Plan 9's
*stats*(8)

# DIAGNOSTICS
An argument that is no option writes the usage.
