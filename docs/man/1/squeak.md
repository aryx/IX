\title{squeak}{1}

# NAME
squeak – Smalltalk, in a window

# SYNOPSIS
**squeak** \[ **-k** *system* ] \[ **-x** *n* ]

# DESCRIPTION
*Squeak* is Smalltalk-80 "made live again, in colour", in a window:
everything on its screen is a morph, drawn by Smalltalk. \man{smalltalk}{1}
is the machine under it. It opens a Browser on the code that draws the
atoms, a Workspace, the Transcript, atoms bouncing, and a car with its
script.

The mouse's buttons, by Smalltalk's colors:

left (red)
:    Picks up what does not want the mouse (a shape, a window by its title)
     and puts it down; in a text sets the caret and selects; in a list
     picks; on the world, its menu.

right (yellow)
:    In a text: do it, print it, inspect it, accept.

middle (blue), or Control and left
:    A halo on the morph, its handles: delete, pick up, duplicate, resize,
     inspect, its viewer.

In the Browser, change `EllipseMorph>>drawOn:` and accept it: the atoms
beside it are drawn the new way at once. Control-C stops what runs too
long. Closing the window ends it, and nothing is saved.

**-k** *system*
:    `squeak`, the default; `mini`, MiniMorphic, Morphic in one file: fifty
     squares bouncing, in black and white.

**-x** *n*
:    The window *n* times the Display's 800 by 600.

# SEE ALSO
\man{smalltalk}{1}

# BUGS
An image cannot be saved from the window: \man{smalltalk}{1}'s **-o** saves
one.
