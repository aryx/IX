\title{mkbootdir}{1}{system}

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
the kernel's devices say they were made. It may be principia's
directory instead: 9pi's date then, found in its image (the word in
the minute before its `pi.5` was compiled), or the time now when
there is no 9pi.

*Out* is a line `9pi bootdir` *kerndate*, then for each file a line
with its name and its size and its bytes, then a line `end`.

It is a program of the host, run when the kernel is built.

**-h**
:    How it is used, on the standard output.

# EXAMPLES
```
mkbootdir bootdir 1757430000 boot=boot.rc rc=mini-rc ed=mini-ed
mkbootdir bootdir ~/principia boot=boot.rc
```

# SEE ALSO
\man{mkcard}{1}

# DIAGNOSTICS
An argument that is not *name*`=`*file*, and a file that cannot be
read, are said; the status is 1.
