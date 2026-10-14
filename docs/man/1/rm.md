\title{rm}{1}{files}

# NAME
rm – files removed

# SYNOPSIS
**rm**
[ **-fr** ]
*file* ...

# DESCRIPTION
*Rm* removes each *file*, and a directory when it is empty.

**-r**
:    A directory with all that is in it.

**-f**
:    Nothing said of what could not be removed, and the status says
     all went well.

# EXAMPLES
```
rm *.o
rm -r /tmp/build
```

# SEE ALSO
\man{mkdir}{1}; Plan 9's *rm*(1)

# DIAGNOSTICS
`rm: x: Directory not empty`: a file not removed is said, the others
are removed, and the status is not empty.
