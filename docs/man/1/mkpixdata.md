\title{mkpixdata}{1}{system}

# NAME
mkpixdata – the pixels' data, from principia's C

# SYNOPSIS
**mkpixdata**
*principia*
*dir*

**mkpixdata**
**-font**
*principia*

# DESCRIPTION
*Mkpixdata* reads principia's `lib_graphics` C where it is data, not
code: `libmemdraw/cmap.c`'s default colour map and `libdraw/defont.c`'s
default font, and writes them as OCaml strings.

Given a *dir*, it writes there `Memdata.ml` and `Memdata.mli`: the
colour map (`cmap2rgb`, 256 colours' red, green and blue; `rgb2cmap`,
by 4-bit red, green and blue) and the font, for the kernel's pixels.

**-font**
:    The font alone, `Font_default.ml`, on the standard output.

Its output is in the repository: the build does not run it, nor need
principia. It is run again when principia's C changes.

**-h**
:    How it is used, on the standard output.

# EXAMPLES
```
mkpixdata ~/principia kernels/9pi/lib_graphics
mkpixdata -font ~/principia > lib_graphics/Font_default.ml
```

# SEE ALSO
\man{mkbootdir}{1}

# DIAGNOSTICS
A file that cannot be read, and a colour map with too few numbers,
are said; the status is 1.
