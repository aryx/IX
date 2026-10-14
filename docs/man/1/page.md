\title{page}{1}{apps}

# NAME
page – a PDF file's pages, or a picture, looked at

# SYNOPSIS
**page**
*file*

**page**
**-t**
*file*

**page**
**-ppm**
*n*
*file*
*out*

# DESCRIPTION
*Page* shows, in a window, the pages of a PDF file, or a picture, a
PNG or a JPEG file, as a document of one page. It draws the pages
itself: the fonts a file names and does not carry are drawn with
Hershey's strokes, at their widths.

In the window:

Space, PageDown, the right arrow
:    The next page; Backspace, PageUp, the left arrow, the one before.

A number, then Enter
:    That page.

The up and down arrows, the wheel
:    The page moved; a button held drags it.

`+`, `-`, `f`
:    Larger, smaller, the window's width again.

`r`, `q`
:    A quarter turn; the end.

**-t**
:    No window: the words of each page, written.

**-ppm** *n*
:    No window: page *n*'s picture written to *out*, a PPM file, a
     pixel a point.

# EXAMPLES
```
page /lib/pdf/troff.pdf
troff -T pdf /lib/man/1/rc > /tmp/rc.pdf; page /tmp/rc.pdf
page -t /lib/pdf/tex.pdf | wc
```

# DIFFERENCES
Plan 9's *page*(1) hands PostScript and PDF to Ghostscript and pictures
to other programs; this one reads PDF itself and does no PostScript,
FAX nor typesetter output. No menu of the pages, no options of
Plan 9's (**-abirPRvVw**, **-p**), no text found or copied.

# SEE ALSO
\man{troff}{1}, \man{office}{1}, \man{rio}{1}; Plan 9's *page*(1)

# DIAGNOSTICS
A file that is no PDF file nor picture is said, and the status is 1.
