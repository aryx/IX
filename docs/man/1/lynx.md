\title{lynx}{1}{browsers}

# NAME
lynx – the web, in a terminal

# SYNOPSIS
**lynx** \[ **-dump** ] \[ **-w** *width* ] *address*

# DESCRIPTION
*Lynx* fetches the page at *address* and writes it as lines of text:
its title and address, its text filled to the width, each link followed
by a number in brackets, then the addresses of the links by their
numbers. The way of CERN's Line Mode Browser, which Lynx's numbered
links come from.

An address is `http://` or `https://` (TLS 1.3, ix's own); an address
without one is a file, when there is a file of that name, and a host
otherwise.

After a page it reads a line from the standard input:

*n*
:    The page of link number *n*.

*address*
:    The page at that address, made whole against the page's own.

**b**
:    Back to the page before.

**q**
:    The end.

An empty line writes the page again.

**-dump**
:    The page written, and no line read after it.

**-w** *width*
:    The width of a line, more than 10: 80 when not said.

Styles, scripts and pictures are not read, and a form cannot be filled
in.

# EXAMPLES
```
lynx -dump http://example.com/
lynx -w 60 index.html
```

# SEE ALSO
\man{netscape}{1}, \man{curl}{1}
