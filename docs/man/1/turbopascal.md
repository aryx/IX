\title{turbopascal}{1}

# NAME
turbopascal – Turbo Pascal's IDE, in a window

# SYNOPSIS
**turbopascal**
[ **-scale** *n* ]
[ **-rows** *n* ]
[ **-cols** *n* ]

# DESCRIPTION
*Turbopascal* is Turbo Pascal 7's IDE in small, over
\man{pascal}{1}: the blue editor, the menus, a program compiled and
run, an error shown with the cursor on it, the P-code of the
cursor's line, and the debugger (trace into, step over,
breakpoints, watches, the calls). Its text is Plan 9's font, each
character a cell of 9 by 15 pixels, in the PC's 16 colors. A window
made larger has more rows and columns, not larger letters.

The keys:

F9
:    Compile.

Control-F9
:    Run.

F7, F8
:    Trace into, step over.

F10, or Alt and a letter
:    The menus. On mini-9pi, Alt is Plan 9's compose key: F10.

F3, F2
:    Open a file, save it.

F1
:    The keys.

Alt-X
:    End.

Without F keys, Escape then a digit is one (0 for F10), and Control
and a digit is Control and that F key.

**-scale** *n*
:    A pixel of the font is *n* by *n* of the screen's; 2 unless said.

**-rows** *n*, **-cols** *n*
:    The window's size at first; 24 by 80 unless said.

# SEE ALSO
\man{pascal}{1}, \man{turbopascal-tty}{1}

# BUGS
No file is named on the command line: a program is typed, or opened
by F3.
