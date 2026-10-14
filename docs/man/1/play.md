\title{play}{1}

# NAME
play – a file of music played

# SYNOPSIS
**play** \[ **-c** ] \[ **-s** *seconds* ] *file*

# DESCRIPTION
*Play* plays the sound of *file*, writing its samples to `/dev/audio`:
16 bits, signed, the low byte first, the left channel then the right,
44,100 of each a second, what Plan 9's audio device takes and what a CD
holds. What the file is, is by its name's end:

`.mod`
:    A tracker's module (the Amiga's ProTracker).

`.mid`, `.midi`
:    A MIDI file, its notes played by instruments made here.

`.mp3`, `.mp2`
:    MPEG audio, layers 3 and 2.

`.wav`
:    A WAV file.

`.abc`
:    A tune in the ABC notation.

The file is read whole; its samples are made a block at a time, when
the one before is written, so a device that plays at its own pace paces
the program.

**-c**
:    The samples on the standard output, not to the device: on Linux, for
     another program to play.

**-s** *seconds*
:    No more than that much of the sound.

# EXAMPLES
```
play tune.mod
play -s 10 song.mp3
play -c song.mp3 | aplay -f cd
```

# FILES
`/dev/audio`

# SEE ALSO
\man{rebirth}{1}

# DIAGNOSTICS
A file not read, of a kind not known, or a device that cannot be opened
is said, and the status is `play`.
