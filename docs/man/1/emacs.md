\title{emacs}{1}{devtools}

# NAME
emacs – Emacs, in a window

# SYNOPSIS
**emacs**
[ **-q** ]
[ **-scale** *n* ]
[ **-rows** *n* ]
[ **-cols** *n* ]
[ *file* ]

# DESCRIPTION
*Emacs* is ix's Emacs, mini-emacs, in a window: in a window of
\man{rio}{1} on Plan 9, in an SDL window on Linux. It opens *file*,
made when it is saved if it is not there, or a directory, a list of
its files. Its keys and its modes are those of \man{emacs-tty}{1},
the same editor in a terminal; here a click puts the point and the
wheel scrolls. The text is Plan 9's font, Latin's letters only. A
window made larger has more rows and columns, not larger letters.

**-q**
:    Without the author's configuration: its colors and its keys.

**-scale** *n*
:    On Linux: a pixel of the font is *n* by *n* of the screen's (2).

**-rows** *n*, **-cols** *n*
:    On Linux: the window at first (40 by 100).

**-time**
:    On Plan 9: the milliseconds of each painting, on the console.

**-h**
:    How.

# EXAMPLES
```
emacs notes.txt
emacs -q /src
```

# DIFFERENCES
Plan 9 has no Emacs: its *emacs*(1) is a page left blank on purpose.
This one is ix's own.

# SEE ALSO
\man{emacs-tty}{1}, \man{ed}{1}, \man{turbopascal}{1}

# BUGS
A character that is not Latin is not drawn.
