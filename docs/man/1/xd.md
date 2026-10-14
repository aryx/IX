\title{xd}{1}{files}

# NAME
xd – a file's bytes shown

# SYNOPSIS
**xd**
[ *option* ... ]
[ *format* ... ]
[ *file* ... ]

# DESCRIPTION
*Xd* writes the bytes of each *file*, or of the standard input, 16 a
line after their address; with no *format*, as numbers of 4 bytes in
hexadecimal, the high byte first. A line for each *format* given:

**-c**
:    The characters; a byte that is none, in hexadecimal.

**-**{**b1w2l4v8**}{**odx**}
:    Numbers of 1, 2, 4 or 8 bytes, in octal, decimal or hexadecimal
     (`-bx`: bytes in hexadecimal).

**-a**{**odx**}
:    The address's base.

**-r**
:    Lines the same as the one before are one `*`.

**-s**
:    The bytes of each 4 turned around first.

**-u**
:    Taken: the output is not kept anyway.

The last line is the file's length.

# EXAMPLES
```
echo hello | xd -c -bx
```

# DIFFERENCES
No **-R** (characters of several bytes).

# SEE ALSO
\man{cmp}{1}; Plan 9's *xd*(1)
