\title{ed}{1}{text}

# NAME
ed – the line editor

# SYNOPSIS
**ed**
[ **-** ]
[ **-o** ]
[ *file* ]

# DESCRIPTION
*Ed* edits a buffer of numbered lines that is never shown, by commands
read from the standard input, one a line: addresses, then a letter.
*File* is read into the buffer and remembered, as `e` *file* would.
The commands are Plan 9's, all of them (`a i c d s m t j k g v u w r e
q !`...), and so are the regular expressions, with `|` and `( )`;
*ed*(1) of Plan 9 tells them. A file's characters are UTF-8's.

**-**
:    Quiet: no counts, no `!` after a shell command; `q` and `e` even
     when the buffer is not written.

**-o**
:    A filter: the file is the standard output, the rest the standard
     error, and *ed* starts adding lines (`ed -o < text`, the commands
     after the `.`).

**-h**
:    A session, by example.

# EXAMPLES
```
ed notes
a
hello, world
.
,s/world/ed/
w
q
```

# SEE ALSO
\man{sed}{1}, \man{grep}{1}, \man{emacs}{1}; *ed*(1), *regexp*(6)

# DIAGNOSTICS
An error is a `?`, nothing more. An interrupt prints `?` and goes back
to the commands; a hangup writes the buffer to `ed.hup`. The status is
always 0.
