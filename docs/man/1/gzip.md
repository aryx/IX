\title{gzip}{1}{files}

# NAME
gzip, gunzip – files compressed, and back

# SYNOPSIS
**gzip**
[ **-cv** ]
[ **-1**...**-9** ]
[ *file* ... ]

**gunzip**
[ **-ctvT** ]
[ *file* ... ]

# DESCRIPTION
*Gzip* compresses each *file* into one in the current directory, named
after it with `.gz` (a `.tar`'s with `.tgz`), and leaves the file as
it is. Without a *file*, it compresses its standard input to its
standard output.

*Gunzip* does the opposite: each `.gz` file uncompressed into one
without the `.gz` (a `.tgz`'s with `.tar`), or the standard input to
the standard output. A file of several gzip files end to end is
uncompressed into one.

**-c**
:    To the standard output, not a file.

**-v**
:    What is compressed or uncompressed into what, on the standard
     error.

**-1** ... **-9**
:    The level: taken, and all the same here.

**-t**
:    (*gunzip*) Nothing written: the names in the file listed, with
     **-v** each one's length and time.

**-T**
:    (*gunzip*) The output given the time written in the file.

# EXAMPLES
```
gzip -v notes
gunzip -c notes.gz | wc
tar c src | gzip > src.tgz
```

# DIFFERENCES
The file's header and trailer are Plan 9's gzip's bytes; what is
between, the compressed data, is not: its compressor writes deflate's
fixed codes only, so the file is bigger, and the level does nothing.
Any gunzip reads it.

# SEE ALSO
\man{tar}{1}; Plan 9's *gzip*(1)

# DIAGNOSTICS
The status is `errors` when a file could not be read or written, or
was not a gzip file, or its data were corrupt; a corrupt file's output
is removed.
