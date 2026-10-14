\title{drscheme}{1}

# NAME
drscheme – an environment for learning to program, in Scheme

# SYNOPSIS
**drscheme** \[ **-h** ] \[ `size=`*n* ]

# DESCRIPTION
*Drscheme* is DrScheme small, in the look of its version 209 (2004):
the program in the Definitions window above, a prompt in the
Interactions window below, and Execute between them. Execute runs the
definitions on a new Scheme machine, from nothing, and leaves it to the
prompt, whose expressions see what was defined.

Control-T, or the Execute button
:    Runs the definitions.

Enter at the prompt
:    Evaluates what was typed.

Control-B, or the Break button
:    Stops a program that does not end.

The Step button
:    The stepper: the evaluation shown as a series of rewritings, what is
     rewritten in green and what replaced it in purple. Escape closes it.

A click on `Language:`
:    Beginning Student, or Standard (R5RS).

Control-Q
:    The end.

A program runs a number of steps at each frame, so one that does not
end leaves the window alive. An error is said below and the expression
that failed painted pink above. An image is a value,
`(circle 20 "solid" "red")` a red disc at the prompt, and `big-bang`
runs a world in the window.

**-h**
:    The keys, and the end.

`size=`*n*
:    The window *n* pixels square at first (1000 on Linux; on Plan 9 the
     window's, or the screen's).

# SEE ALSO
\man{scheme}{1}, \man{turbopascal}{1}
