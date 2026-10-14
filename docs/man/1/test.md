\title{test}{1}{shell}

# NAME
test – a question, answered by the status

# SYNOPSIS
**test**
*expr*

# DESCRIPTION
*Test* writes nothing: its status is empty when *expr* is true, and
`false` when not, for rc's `if`. Each operator and operand is an
argument of its own.

**-e**, **-f**, **-d**, **-s** *file*
:    *File* is there; is a file; a directory; is not empty.

**-r**, **-w**, **-x** *file*
:    *File* may be read, written, run (its permissions).

**-A**, **-L**, **-T** *file*
:    *File* is append only, exclusive, temporary: Plan 9's bits.

**-t** [ *fd* ]
:    The descriptor (1) is the console.

*s*, **-n** *s*, **-z** *s*
:    The string is not empty; the same; is empty.

*a* **=** *b*, *a* **!=** *b*
:    Two strings the same, or not.

*m* **-eq** *n*
:    Two numbers: **-ne**, **-gt**, **-lt**, **-ge**, **-le** too.

*f* **-nt** *g*, *f* **-ot** *g*
:    *F* is newer, older, than *g*.

*f* **-older** *t*
:    *F* was written before *t*: seconds since 1970, or a time ago,
     `3d12h` (`y M d h m s`).

**!**, **-a**, **-o**, **(** *expr* **)**
:    Not, and, or, grouping.

# EXAMPLES
```
if(test -d $dir) echo $dir is a directory
if(test $#* -gt 2) echo too many
```

# DIFFERENCES
No **-l** *string* (a string's length as a number). **-r**, **-w** and
**-x** read the file's permissions where Plan 9's tries to open it.
**-b**, **-c**, **-u** and **-g** are false, as Plan 9's.

# SEE ALSO
\man{rc}{1}; *test*(1)
