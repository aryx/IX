\title{du}{1}{files}

# NAME
du – how much a directory holds

# SYNOPSIS
**du**
[ **-afns** ]
[ **-b** *size* ]
[ *file* ... ]

# DESCRIPTION
*Du* writes how much each *file* holds, in KB, and each directory
under it: its files' lengths, each rounded up to a block (1 KB),
added; with no *file*, the current directory. A directory reached
twice (a union, a bind) is counted once.

**-a**
:    Each file too.

**-s**
:    Only the *files* named.

**-n**
:    In bytes, each file.

**-b** *size*
:    The block, in bytes (`4k`: 4096).

**-f**
:    Nothing said of what cannot be read.

# EXAMPLES
```
du -s /usr/pad
```

# DIFFERENCES
No **-e**, **-h**, **-p** (other units), **-q**, **-t**, **-u** (a
qid or a time in place of the size), **-r**.

# SEE ALSO
\man{ls}{1}, \man{walk}{1}; Plan 9's *du*(1)

# BUGS
Its usage names Plan 9's options, which it refuses.
