\title{settings}{1}{system}

# NAME
settings – the desktop's settings: wallpaper, clock, panel, mouse, volume

# SYNOPSIS
**settings** [**-apply**]

# DESCRIPTION
*Settings* shows, in a window, the wallpaper's colour or picture (a
JPEG or PNG file, its path typed, then **Use**), the clock's form (24
hours, 12, or none), the side of the screen the panel is on, the mouse's
buttons swapped or not and whether it goes faster, and the volume; and,
below, what the machine is. A press changes a setting at once: it is
written to `$home/lib/desktop/settings`, which \man{panel}{1} looks at
every second and \man{desk}{1} every two, and the mouse's and the
volume's are told to `/dev/mousectl` and `/dev/volume`. **q** ends it.

With **-apply**, no window: the file's mouse and volume are told to the
kernel, and it ends. *Desktop* says it first, so that they hold after a
boot.

The file has a line a setting, `wallpaper=colour 3a5f85` or
`wallpaper=picture` *file*, `clock=24`, `edge=bottom`, `swap=no`,
`accelerated=no`, `volume=70`; a line not known is left out.

# FILES
`$home/lib/desktop/settings`, `/dev/mousectl`, `/dev/volume`

# SEE ALSO
\man{panel}{1}, \man{desk}{1}, \man{rio}{1}
