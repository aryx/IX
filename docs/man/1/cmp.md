\title{cmp}{1}{files}

# NAME
cmp – two files' bytes compared

# SYNOPSIS
**cmp**
[ **-lLs** ]
*file1*
*file2*
[ *offset1* [ *offset2* ] ]

# DESCRIPTION
*Cmp* says nothing when the two files are the same; else where they
first differ, the byte's number (from 1), or which one ended first.
The *offsets* say where to start in each, in bytes.

**-l**
:    Each byte that differs: its number, and the two in hexadecimal.

**-L**
:    The line of the first that differs, too.

**-s**
:    Nothing said: the status only.

# EXAMPLES
```
cmp a.out b.out
if(cmp -s old new) echo same
```

# DIFFERENCES
An offset is decimal, or hexadecimal after `0x`; one that starts with
`0` is not octal.

# SEE ALSO
\man{diff}{1}, \man{xd}{1}; Plan 9's *cmp*(1)

# DIAGNOSTICS
The status is empty when the files are the same, `EOF` when one is
the other with more after it, `differ` otherwise, `open` when one
cannot be opened.
