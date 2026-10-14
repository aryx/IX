\title{mkbootdir}{1}

# NAME
mkbootdir – the files of a kernel's own image, its /boot

# SYNOPSIS
**mkbootdir**
*out*
*kerndate*
*name*`=`*file* ...

# DESCRIPTION
*Mkbootdir* packs the *files* into *out*, which is linked into
mini-9pi's kernel: there the kernel serves them as `/boot`, each
under its *name*, before any disk is read. `/boot/boot`, a script,
is the first process.

*Kerndate*, in seconds since 1970, is the files' date, and the date
the kernel's devices say they were made.

*Out* is a line `9pi bootdir` *kerndate*, then for each file a line
with its name and its size and its bytes, then a line `end`.

It is a program of the host, run when the kernel is built.

**-h**
:    How it is used, on the standard output.

# EXAMPLES
```
mkbootdir bootdir 1757430000 boot=boot.rc rc=mini-rc ed=mini-ed
```

# SEE ALSO
\man{mkcard}{1}

# DIAGNOSTICS
An argument that is not *name*`=`*file*, and a file that cannot be
read, are said; the status is 1.
