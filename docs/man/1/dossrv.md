\title{dossrv}{1}

# NAME
dossrv – a FAT file system served as files

# SYNOPSIS
**dossrv**
[ **-v** ]
[ **-s** ]
[ **-f** *devicefile* ]
[ *srvname* ]

# DESCRIPTION
*Dossrv* is a file server for MS-DOS's file systems: it posts
`/srv/`*srvname* (`/srv/dos` when there is none) and returns, a
process of its own serving it. A \man{mount}{1} of that file, with a
device's file as what to attach, gives the device's FAT as a tree of
files.

Files are read, written, made and removed; a device that cannot be
opened for writing is served for reading. A *wstat* changes a name,
a time, and whether a file is only read. The files are bill's and
trog's, `rw-rw-rw-`; a name is found whatever its letters' case, and
shown in the case it was written with.

**-f** *devicefile*
:    The device served when a mount names none.

**-v**, **-s**
:    Taken, and nothing done: Plan 9's dossrv's.

# EXAMPLES
The card's first partition, the firmware's:

```
dossrv
mount -c /srv/dos /n/c /dev/sdM0/dos
ls /n/c
```

# FILES
`/srv/dos`

# SEE ALSO
\man{mount}{1}, \man{fdisk}{1}, \man{mkcard}{1}, *dossrv*(4) in
Plan 9's manual

# DIAGNOSTICS
A mount with no device, of the command or of **-f**, is refused:
`no file system device specified`.

# BUGS
No long names (VFAT's): a name is of 8.3 characters.
