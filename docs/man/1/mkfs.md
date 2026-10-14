\title{mkfs}{1}{system}

# NAME
mkfs – an image of xv6's file system, with files in it

# SYNOPSIS
**mkfs**
[ **-m** *megabytes* ]
[ **-b** *blocksize* ]
[ **-i** *inodes* ]
*out*
*name*`=`*file* | *directory*`/` ...

# DESCRIPTION
*Mkfs* writes into *out* the bytes of a disk with xv6's file system
(with ix's larger files), holding each *file* under its *name*; a
*name* with `/` makes the directories on its way, and one that ends
with `/` is a directory, empty. It is a host's program, for an SD
card's second partition (\man{mkcard}{1} **-fs**), made with the code
mini-9pi's kernel reads it with.

**-m** *megabytes*
:    The image's size: 32 otherwise.

**-b** *blocksize*
:    The block's size in bytes: 1024 otherwise.

**-i** *inodes*
:    How many files and directories it may hold: 200 otherwise, xv6's.

# EXAMPLES
```
mkfs fs.img readme=README.md bin/hello=hello usr/pad/ tmp/
mkcard -fs fs.img card.img ...
```

# DIFFERENCES
Another program under the same name: Plan 9's *mkfs*(8) copies a tree
described by a proto file into a *kfs* or an archive. This one makes
an xv6 image from a list of names.

# SEE ALSO
\man{mkcard}{1}, \man{mkbootdir}{1}; Plan 9's *mkfs*(8)

# BUGS
A name is 14 characters at most (xv6's).
