\title{troff}{1}

# NAME
troff – a document typeset, for a terminal or as a PDF file

# SYNOPSIS
**troff**
[ **-man** | **-ms** | **-md** | **-latex** ]
[ **-T** *way* ]
[ *file* ... ]

# DESCRIPTION
*Troff* reads the *files*, or the standard input when there is
none, and writes each as a document on the standard output: for a
terminal, its lines filled to 65 letters, or as the sheets of a PDF
file, to print or for \man{page}{1}.

It has troff's name and reads what was written for troff, but it is
not troff: it knows the macros of a package, not the requests they
were made of. What it does not understand it says on the standard
error, with the file's name and the line; nothing is left out in
silence.

What a file is written in is said by an option, or found:

**-man**
:    A manual page: the macros of *man*(6). A file with a line that
     starts with `.TH` is one.

**-ms**
:    A paper: the macros of *ms*(6), with its tables (*tbl*'s `.TS`)
     and its pictures (*pic*'s `.PS`). A file that is nothing else
     is one.

**-md**
:    A document in Markdown's lines, with `\name[options]{text}` for
     what Markdown has not. A file named `.md` or `.ixd` is one, and
     a file whose first line is a `\title`: this page.

**-latex**
:    Simple LaTeX, with noweb's chunks of code: a book. A file named
     `.tex` or `.nw` is one.

How it is written is said by **-T**:

**-T text**
:    For a terminal. What is done with no **-T**.

**-T pdf**
:    A PDF file: one *file* read. Times and Courier are named in it
     and not carried; a character they have not is a `?`, and said.

**-T md**
:    The document written again in Markdown's lines, whatever it was
     read from: a manual page converted.

**-T words**
:    What the PDF file's words are, as text.

# EXAMPLES
A page on the screen, and the same as a file to look at:

```
troff /lib/man/1/troff
troff -T pdf /lib/man/1/troff > /tmp/troff.pdf
page /tmp/troff.pdf
```

A manual page of Plan 9's written in Markdown's lines:

```
troff -T md tr.1 > tr.md
```

# SEE ALSO
\man{man}{1}, \man{page}{1}

# BUGS
No equation is set: an `.EQ` is passed over, and said.
Words are not cut at a line's end, so some lines are loose.
A picture from a file is its name.
