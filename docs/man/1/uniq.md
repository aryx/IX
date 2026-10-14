\title{uniq}{1}{text}

# NAME
uniq – of the same lines in a row, one

# SYNOPSIS
**uniq**
[ **-udc** [ **+**|\strong{-}\emph{num} ] ]
[ *file* ]

# DESCRIPTION
*Uniq* writes the lines of *file*, or of the standard input, but of
lines that follow each other and are the same, only the first. Lines
the same but apart are not seen: \man{sort}{1} brings them together.

**-u**
:    Only the lines that are alone.

**-d**
:    Only one of each of those that are not.

**-c**
:    Each line with how many times it was there.

\strong{-}\emph{num}
:    The lines compared without their *num* first fields.

\strong{+}\emph{num}
:    And without *num* characters more.

# EXAMPLES
A text's most frequent words:

```
tr -cs A-Za-z '\012' < text | sort | uniq -c | sort -rn | sed 10q
```

# SEE ALSO
\man{sort}{1}, \man{tr}{1}; *uniq*(1)

# BUGS
A last line without its newline is not read, as Plan 9's.
