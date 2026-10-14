\title{smalltalk}{1}

# NAME
smalltalk – Smalltalk-80, on a terminal

# SYNOPSIS
**smalltalk** \[ **-k** *system* ] \[ **-i** *image* ] \[ **-e**
*expression* ... ] \[ **-world** *n* ] \[ **-size** *w*`x`*h* ] \[
**-o** *image* ] \[ **-ppm** *file* ] \[ **-s** ] \[ *file.st* ... ]

# DESCRIPTION
*Smalltalk* is Smalltalk-80 as the Blue Book describes it (Goldberg and
Robson, 1983): its compiler, its interpreter of bytecodes over a table
of objects, and its system, which is Smalltalk's own text, compiled
when it starts.

The *files* are filed in, in order, in the chunk format: a class's
definition, its methods after `!`*Class* `methodsFor: '`*category*`'!`,
and expressions to run. Then each **-e** is evaluated and its answer
written, as "print it" does. With no **-e** and no file, each line of
the standard input is an expression, its answer written.

**-k** *system*
:    `blue`, the Blue Book's (the default); `squeak`, with Squeak's
     closures, color, Morphic, tools and Etoys; `quiet`, the same with
     nothing that moves by itself in its world; `mini`, with MiniMorphic,
     Morphic in one file.

**-i** *image*
:    The system as an image saved it: nothing is compiled, and **-k** is not
     looked at.

**-o** *image*
:    The system saved, at the end.

**-world** *n*
:    With `squeak` or `mini`: the system started as a window starts it, a
     world on the Display (for Squeak a Browser, a Workspace, the
     Transcript, atoms and a car), then *n* of its cycles, 20 ms of its
     clock each, before the files and the expressions. With **-i**, the
     image's world is cycled.

**-size** *w*`x`*h*
:    The Display's size for a new world: 800x600 when not said.

**-ppm** *file*
:    The Display written at the end, as a PPM picture.

**-s**
:    The number of bytecodes run, said at the end.

There is no window: what is drawn is seen with **-ppm**; \man{squeak}{1} is
the window.

# EXAMPLES
```
smalltalk -e '3 + 4' -e '100 factorial printString size'
smalltalk Mine.st -e 'Mine new answer'
smalltalk -k squeak -o squeak.image
smalltalk -i squeak.image -world 3 -ppm screen.ppm
```

# SEE ALSO
\man{squeak}{1}

# DIAGNOSTICS
An error is said, and the status is 1.
