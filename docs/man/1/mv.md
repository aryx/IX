\title{mv}{1}{files}

# NAME
mv – a file under another name

# SYNOPSIS
**mv**
*fromfile*
*tofile*

**mv**
*fromfile* ...
*todir*

# DESCRIPTION
*Mv* gives *fromfile* the name *tofile*, or puts each *fromfile* in
the directory *todir* under its own name. What is at the new name is
removed first.

In the same directory only the name is changed: the file stays as it
is, and a directory may be renamed so. Into another directory the
file is copied there, with its time, and the old one removed: 9P has
no way to move a file, and a directory is refused.

# EXAMPLES
```
mv notes.txt notes.old
mv *.ml src
```

# SEE ALSO
\man{cp}{1}, \man{rm}{1}; Plan 9's *mv* is in its *cp*(1)

# DIAGNOSTICS
A file that could not be moved is said and the next tried; the
status is then `failure`. A file moved onto itself is refused.
