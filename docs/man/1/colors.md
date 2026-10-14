\title{colors}{1}{apps}

# NAME
colors – Plan 9's color map

# SYNOPSIS
**colors**
[ **-rx** ]

# DESCRIPTION
*Colors* draws, in its window, the 256 colors of Plan 9's color map,
a square each, sixteen a row, the last one first. The left button on
a square writes its number, its red, green and blue, and its 32-bit
value; the right button's menu has `exit`.

**-r**
:    A ramp of 256 greys instead.

**-x**
:    The numbers in hexadecimal.

# EXAMPLES
```
colors -x &
```

# DIFFERENCES
The map's colors whatever the screen is; no *getmap*, there being no
map to load on ix's screens.

# SEE ALSO
\man{rio}{1}, \man{stats}{1}; Plan 9's *colors*(1), and *color*(6)
for why the map is so made

# DIAGNOSTICS
An option not known writes the usage.
