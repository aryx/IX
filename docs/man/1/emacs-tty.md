\title{emacs-tty}{1}{devtools}

# NAME
emacs-tty – Emacs, in a terminal

# SYNOPSIS
**emacs-tty** \[ **-q** ] \[ **-keys** *script* \[ **-colors** ] \[
**-frame** *file.ppm* ] ] \[ *file* ]

# DESCRIPTION
*Emacs-tty* is ix's Emacs, mini-emacs, in the terminal it is started
from rather than in a window: the same editor, its cells drawn with the
terminal's escapes. It opens *file*, which is made when it is saved if
it is not there, or a directory, a list of its files (Enter opens one).

Its keys are Emacs's: C-f C-b C-n C-p and the arrows, C-a C-e, M-f M-b,
M-< M->, C-v M-v, C-l; C-d, C-k, C-w, M-w, C-y, M-y, and C-\_ undoes;
C-s and C-r search, M-% replaces; C-x C-f a file, C-x b a buffer, C-x
C-b the buffers; C-x 2, C-x 3, C-x o, C-x 0, C-x 1 the windows; M-u M-l
M-c a word's case, C-t, M-q fills a paragraph, M-g a line by its
number; C-x ( C-x ) C-x e a keyboard macro; M-x a command by its name;
C-x C-s saves, C-x C-c ends it. Meta is Alt, or Escape before the key.

A file's colors are its language's, by its name's end: `.ml`, `.c`,
`.h`, `.s`, `.st`, `.scm`, `.pas`, `.pl`, `.dl`. There Tab indents (but
in C and assembly) and C-j is a new line indented.

**-q**
:    Without the author's configuration: its colors on a dark ground, a
     directory's files colored, y for yes.

**-keys** *script*
:    No terminal: the keys of *script* are given (`C-x`, `A-f`, `Enter`,
     `ArrowDown`, `Escape`, `Space`, `=`*text*; *rows*`x`*columns* the
     screen's size; `Click@`*row*`,`*column* and `WheelUp@`*row*`,`*column*
     the mouse), and the screen they leave is written as text. What the
     tests use.

**-colors**
:    With **-keys**: under each row, how its cells are shown (`r`, `g`, `y`,
     `b`, `m`, `c` a color; a capital, bold; `#`, reversed).

**-frame** *file.ppm*
:    With **-keys**: the screen written as the picture a window would show.

# EXAMPLES
```
emacs-tty notes.txt
emacs-tty -keys 'C-x C-f =x.ml Enter' -colors
```

# SEE ALSO
\man{turbopascal-tty}{1}, \man{ed}{1}
