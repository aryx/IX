\title{tee}{1}{text}

# NAME
tee – the input copied to files too

# SYNOPSIS
**tee**
[ **-i** ]
[ **-a** ]
*file* ...

# DESCRIPTION
*Tee* copies the standard input to the standard output and to each
*file*, made or emptied first. A file that cannot be opened is said,
and the others written.

**-a**
:    Written at the files' ends.

**-i**
:    An interrupt is ignored.

# EXAMPLES
```
mk | tee log | grep warning
```

# SEE ALSO
\man{cat}{1}; *tee*(1)
