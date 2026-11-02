\title{expose}{1}{system}

# NAME
expose – all the windows at once, shrunk side by side

# SYNOPSIS
**window -popup -max -label expose expose**

# DESCRIPTION
*Expose* shows each window of \man{rio}{1}, hidden ones too, shrunk in a
grid over what the screen has for windows, with its label, made again
twice a second. A press on one brings it to the front (back first, when
hidden); a press anywhere else, back as before. \man{panel}{1}'s button
beside **Start** starts it.

It opens each window's image by the name in its `winname` file and asks
the draw device to draw it smaller (mini-9pi's draw message `Z`, k times
smaller, k a whole number): mini-9pi keeps every window's pixels whole,
covered or not.

# FILES
`/dev/wsys`, the windows and their `winname`

# DIFFERENCES
Apple's Exposé (2003) slides the windows to their places; this one does
not. Without the draw device's `Z` (the C pixels, `PIXEL=c`) a window is a
grey box with its name.

# SEE ALSO
\man{panel}{1}, \man{rio}{1}
