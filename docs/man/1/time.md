\title{time}{1}{processes}

# NAME
time – a command timed

# SYNOPSIS
**time**
*command*
[ *arg* ... ]

# DESCRIPTION
*Time* runs *command* with its *args*, waits for it, then writes on
the standard error the time it took, in seconds: in its program
(`u`), in the kernel for it (`s`), from its start to its end (`r`);
then the command's first five words. A command whose name is no path
is also looked for in `/bin`.

If the command failed, its status is written after it, `# status=`,
and is *time*'s.

# EXAMPLES
```
% time ls -l /bin
0.01u 0.02s 0.05r 	 ls -l /bin
```

# DIFFERENCES
None in what it does. The times are the kernel's, given with the
command's end: on another system than Plan 9's, they are zeros.

# SEE ALSO
\man{sleep}{1}, \man{spin}{1}; Plan 9's *time*(1)

# DIAGNOSTICS
A command that cannot be run is said; `usage: time command` with no
command.
