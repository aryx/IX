\title{ps}{1}{processes}

# NAME
ps – the processes

# SYNOPSIS
**ps**
[ **-apr** ]

# DESCRIPTION
*Ps* writes a line for each process, in the order of their numbers:
its owner, its number, the time it spent in its program and in the
kernel for it (minutes and seconds), its memory, its state and its
name. All of it is read in `/proc`: a directory a process, its
`status` a line of words.

**-a**
:    The process's arguments, from `/proc/`*n*`/args`, in place of
     its name.

**-p**
:    Its two priorities, after the times.

**-r**
:    The time since it started, after the number.

# EXAMPLES
```
ps -a
ps | grep rio
```

# FILES
`/proc/*/status`, `/proc/*/args`

# DIFFERENCES
No *psu*: the owner is in each line, for \man{grep}{1}. A letter that
is not one of the three is taken and nothing done.

# SEE ALSO
\man{free}{1}, \man{stats}{1}; Plan 9's *ps*(1), whose page says
what each state means

# DIAGNOSTICS
No `/proc`, or no process in it, is said, and the status is not
empty.

# BUGS
On another system than Plan 9's, `/proc` is read as if it were: on
Linux, lines of words that mean nothing.
