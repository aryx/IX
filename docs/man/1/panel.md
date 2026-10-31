\title{panel}{1}{system}

# NAME
panel – the bar of the desktop: a start button, the windows, a clock

# SYNOPSIS
**window -panel -edge bottom 28 panel** [**-noclock**]

# DESCRIPTION
*Panel* draws a bar in a window of \man{rio}{1}'s panel layer, which
stays above the other windows and takes no keyboard. It has a button for
each window, in the order they were made: a press brings that window to
the front; on the one that has the keyboard, hides it; on a hidden one,
brings it back. The start button shows or hides the popup window
labelled `startmenu`, and does nothing when there is none. The clock
says the time in GMT; **-noclock** leaves it out.

It looks at `/dev/wsys` once a second, so a new window has its button
within a second.

# FILES
`/dev/wsys`, the windows; `/dev/wctl`, where it asks

# SEE ALSO
\man{rio}{1}
