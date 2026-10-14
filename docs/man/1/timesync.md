\title{timesync}{1}{system}

# NAME
timesync – the time a server of the network says

# SYNOPSIS
**timesync**
*server*

# DESCRIPTION
*Timesync* asks *server* the time by SNTP (one packet to UDP's port
123, one answer) and writes it on the standard output as the seconds
since 1970: what a machine without a clock chip, a Raspberry Pi, gives
its `/dev/time` when it starts.

# EXAMPLES
```
timesync pool.ntp.org > /dev/time
```

# DIFFERENCES
Plan 9's *timesync*(8) is a process that keeps the clock right, from
a file server, NTP servers or a radio clock, measuring the delay and
the clock's frequency. This one asks once, believes one server, and
leaves the writing to the shell.

# SEE ALSO
\man{curl}{1}; Plan 9's *timesync*(8)

# DIAGNOSTICS
No answer, no address, or the system's reason (`Connection refused`)
is said, nothing is written, and the status is not empty.
