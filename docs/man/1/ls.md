\title{ls}{1}{files}

# NAME
ls – a directory's entries, or a file's own

# SYNOPSIS
**ls**
[ **-dlmnpqrstuFQT** ]
[ *name* ... ]

# DESCRIPTION
*Ls* writes, for each directory *name*, its entries, and for each
other *name*, itself, one a line, sorted by name; with no *name*, the
current directory's. Its lines are Plan 9's, byte for byte.

**-l**
:    The long line: the mode, the device's letter and number, the
     owner, the group, the length, the date.

**-d**
:    A directory itself, and not its entries.

**-s**
:    The size in KB, first.

**-m**
:    Who wrote the file last.

**-q**
:    The qid.

**-T**
:    The temporary bit.

**-F**
:    A `/` after a directory, a `*` after what can be run.

**-t**
:    By the time written, the latest first; **-u**: the time read.

**-r**, **-n**
:    The order reversed; not sorted.

**-p**, **-Q**
:    Only a name's last part; a name never quoted.

# EXAMPLES
```
ls -l /bin
ls -lt | sed 5q
```

# DIFFERENCES
No *lc* (columns). The dates are GMT's: `/env/timezone` is not read.

# SEE ALSO
\man{du}{1}, \man{walk}{1}; Plan 9's *ls*(1)

# DIAGNOSTICS
A name that is not there is said, and the others are listed.
