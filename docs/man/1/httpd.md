\title{httpd}{1}{network}

# NAME
httpd – a directory's files served over HTTP, to this machine

# SYNOPSIS
**httpd**
[ **-p** *port* ]
[ *directory* ]

# DESCRIPTION
*Httpd* serves the files of *directory* (`.` when not said) on
`http://127.0.0.1:`*port*`/`, to this machine only, a client at a
time. Its first line says where; then each request is a line, its
method, its target, its status and the length of its answer:

```
serving notes on http://127.0.0.1:8000/
GET /a.html 200 153
```

A file is answered with its type, by its name's end; a directory
with its `index.html`, or a page that lists it, each name a link;
a directory named without its `/` is sent there (301). Nothing above
*directory* is served (403), and only `GET` (405). A query is
dropped, `%20` decoded.

**-p** *port*
:    The port, 8000 when not said; 0, one the system chooses.

# EXAMPLES
```
httpd -p 8080 /lib/doc &
lynx 127.0.0.1:8080
```

# DIFFERENCES
Plan 9's *httpd*(8) serves `/usr/web` to the network, with its
namespace file, redirections, CGI-like programs (*save*, *imagemap*,
*man2html*, *webls*) and TLS. This one is ix's: a directory, to this
machine, `GET`, one client at a time, and none of those.

# SEE ALSO
\man{curl}{1}, \man{lynx}{1}, \man{netscape}{1}; Plan 9's *httpd*(8)

# DIAGNOSTICS
A directory that is not one, or a port taken, is said, and the status
is not empty.
