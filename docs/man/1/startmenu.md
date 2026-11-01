\title{startmenu}{1}{system}

# NAME
startmenu – what the start button shows: the programs, with their icons

# SYNOPSIS
**window -popup -hide -label startmenu startmenu**

# DESCRIPTION
*Startmenu* lists the programs of `/lib/desktop/apps`, those on top
directly and the others by their group, in a window of \man{rio}{1}'s
popup layer that \man{panel}{1} shows and hides. The mouse on a group
opens it beside; a press on a program opens it in a new window, in the
middle of what the screen has for windows or on all of it, and hides the
menu, as a press anywhere else does. **Exit** ends *rio*. A program of the table that
is not in `/bin` is not listed.

A line of the table is

    group | name | icon | size | command

*group* being `top`, `apps`, `games`, `net`, `devtools`, `system` or
`examples`; *icon* a file of `/lib/desktop/icons` without its `.txt`;
*size* a width and a height, `640x480`, or `max`.

An icon is text, a character a pixel: first the colours, a character, a
blank and six hexadecimal digits; then rows, all as wide, in which `.` is
no colour. `#` starts a comment. It is drawn at its size.

# FILES
`/lib/desktop/apps`, `/lib/desktop/icons/`

# SEE ALSO
\man{panel}{1}, \man{rio}{1}
