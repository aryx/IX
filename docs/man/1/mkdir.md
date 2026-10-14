\title{mkdir}{1}{files}

# NAME
mkdir – a directory made

# SYNOPSIS
**mkdir**
[ **-p** ]
[ **-m** *mode* ]
*dirname* ...

# DESCRIPTION
*Mkdir* makes each *dirname*, which must not be there.

**-p**
:    The directories of its path that are missing are made too, and
     one that is there is no error.

**-m** *mode*
:    Its permissions, in octal; 777 otherwise.

# EXAMPLES
```
mkdir -p usr/pad/lib
```

# SEE ALSO
\man{rm}{1}; Plan 9's *mkdir*(1)

# DIAGNOSTICS
A directory not made is said (`zz already exists`), the others are
made, and the status is not empty.
