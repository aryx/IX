\title{unmount}{1}{system}

# NAME
unmount – what was bound or mounted taken away

# SYNOPSIS
**unmount**
[ *new* ]
*old*

# DESCRIPTION
*Unmount* takes away from the name space what \man{bind}{1} or
\man{mount}{1} put on *old*: all of it, or, with *new*, only that
part of the union, named as it was to bind.

# EXAMPLES
```
bind -b /usr/glenda/bin /bin
unmount /usr/glenda/bin /bin
unmount /n/c
```

# SEE ALSO
\man{bind}{1}, \man{mount}{1}; Plan 9's *unmount* is in its *bind*(1)

# DIAGNOSTICS
What was not there is said, with the kernel's reason.
