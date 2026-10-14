\title{office}{1}{apps}

# NAME
office – an office suite, in a window

# SYNOPSIS
**office** \[ *name*`=`*value* ... ]

# DESCRIPTION
*Office* is the office suite as people know it today, small: it starts
with a choice of what to make, a document, a spreadsheet, a
presentation, a picture or a drawing, and each opens in its editor.
Every kind can hold the others: a sheet in a letter, a drawing over a
sheet, a picture on a slide. They float where they are put, are
dragged, and resized by a corner; in a text the text runs round them. A
click on one edits it where it is, the menu bar its editor's, and
Escape gives the menu back to the document around it.

The File menu has New, Open, Save, Save As, Export and Exit. A document
is saved in a directory of its own, the store; Export writes it as a
PDF file in the directory the program was started from. The Edit menu's
Undo and Redo go through the document's versions; the Insert menu puts
a text box, a sheet, a picture, a drawing, a chart or an image from a
file in it. Control-Q ends it.

What it is given is a list of *name*`=`*value*:

`size=`*n*
:    The window *n* pixels square at first (1000, or the screen's height if
     less).

# FILES
`$PLAYGROUND_STORE`, or `~/.ix-playground/documents`, on Linux;
`$home/lib/documents` on Plan 9: the store.

# SEE ALSO
\man{page}{1}, \man{drscheme}{1}
