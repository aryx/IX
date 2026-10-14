\title{touch}{1}{files}

# NAME
touch – a file's time set to now

# SYNOPSIS
**touch**
[ **-c** ]
[ **-t** *time* ]
*file* ...

# DESCRIPTION
*Touch* sets each *file*'s time written to now, and makes a file
that is not there, empty.

**-c**
:    No file is made.

**-t** *time*
:    That time, in seconds since 1970, and not now.

# EXAMPLES
```
touch Makefile
touch -t 1000000000 old
```

# SEE ALSO
\man{mtime}{1}, \man{mk}{1}; Plan 9's *touch*(1)

# BUGS
On Linux **-t 0** is now: OCaml's *utimes* takes 0 for the time it is.
