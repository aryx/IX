\title{turbopascal-tty}{1}{languages}

# NAME
turbopascal-tty – Turbo Pascal's IDE, in a terminal

# SYNOPSIS
**turbopascal-tty**
[ **-keys** *script* [ **-frame** *file*`.ppm` ] ]

# DESCRIPTION
*Turbopascal-tty* is \man{turbopascal}{1} in the terminal it is
typed in, of 80 columns by 24 rows at least: the same IDE and the
same keys, but Control-C ends it. It is Linux's: a terminal of
mini-9pi's is not one it knows.

**-keys** *script*
:    No terminal: the keys of *script* are given (`F9`, `C-F9`,
     `A-c`, `Enter`, `ArrowDown`, `=`*text* typed, `16x60` the screen
     made 16 rows of 60 columns), and the screen they leave is printed
     as text.

**-frame** *file*`.ppm`
:    With **-keys**, that screen is written as the picture a window
     shows, a PPM file.

# EXAMPLES
```
turbopascal-tty
turbopascal-tty -keys 'A-c =p'
```

# SEE ALSO
\man{turbopascal}{1}, \man{pascal}{1}
