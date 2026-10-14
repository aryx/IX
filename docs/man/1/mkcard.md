\title{mkcard}{1}{system}

# NAME
mkcard – an SD card's image for a Raspberry Pi

# SYNOPSIS
**mkcard**
[ **-m** *megabytes* ]
[ **-fat** *megabytes* ]
[ **-date** *seconds* ]
[ **-fs** *image* ]
*out*
*name*`=`*file* ...

# DESCRIPTION
*Mkcard* writes in *out* the image of a card that a Pi boots from:
an MBR with two partitions, the first a FAT16, from the card's first
megabyte, with the *files* at its root under their *names*, the
second to the card's end.

The firmware reads the first partition before any kernel runs: its
own files, `config.txt`, the kernels must be there. Once booted,
mini-9pi serves it by \man{dossrv}{1}, and the second by its own
file system.

**-m** *megabytes*
:    The card's size; 64 when not said. QEMU wants a power of 2.

**-fat** *megabytes*
:    The first partition's size; 32 when not said. A FAT16 is of 8
     to 128 megabytes.

**-date** *seconds*
:    The files' date, in seconds since 1970; 0, the default, is
     1980-01-01, FAT's first day.

**-fs** *image*
:    The second partition's bytes, a file system's image; zeros
     otherwise.

**-h**
:    How it is used, on the standard output.

It is a program of the host, run when the card is made.

# EXAMPLES
```
mkcard card.img bootcode.bin=firmware/pi1/bootcode.bin \
    config.txt=config.txt kernel.img=kernel-pi1.img
mkcard -m 128 -fat 64 -fs fs.img card.img ...
```

# SEE ALSO
\man{mkbootdir}{1}, \man{fdisk}{1}, \man{dossrv}{1}, \man{mkfs}{1}

# DIAGNOSTICS
Said, with no image written: a name not of 8.3 characters or of
both cases in one part, files that do not fit in the partition, a
partition that does not fit in the card.

# BUGS
Files at the root only, and no long names.
