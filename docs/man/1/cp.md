\title{cp}{1}{files}

# NAME
cp – a file's bytes copied into another

# SYNOPSIS
**cp**
*fromfile*
*tofile*

**cp**
*fromfile* ...
*todir*

# DESCRIPTION
*Cp* copies *fromfile* into *tofile*, made with *fromfile*'s
permissions, or emptied first when it is there. With several
*fromfiles*, or when the last name is a directory, each is copied
into *todir* under its own name. A directory is not copied, and a
file is not copied onto itself.

# EXAMPLES
```
cp notes notes.old
cp *.ml /tmp
```

# DIFFERENCES
No **-g**, **-u**, **-x** (the copy given the old file's group, owner,
time or mode: a *wstat*, which ix's system has not), and no *fcp*.
*mv* has a page of its own, \man{mv}{1}.

# SEE ALSO
\man{mv}{1}, \man{rm}{1}; Plan 9's *cp*(1)

# DIAGNOSTICS
A file that could not be copied is said and the next tried; the
status is then `errors`.
