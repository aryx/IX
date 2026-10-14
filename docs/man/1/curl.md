\title{curl}{1}

# NAME
curl – a URL's bytes on the standard output

# SYNOPSIS
**curl**
[ **-i** ]
[ **-L** ]
[ **-v** ]
[ **-f** ]
[ **-d** *data* ]
[ **-o** *file* ]
[ **--cacert** *file* ]
*url*

# DESCRIPTION
*Curl* asks a web server for *url* and writes the body of its
answer on the standard output. An `http://` URL is asked over a
connection, an `https://` one inside TLS 1.3, the server's
certificate checked against the system's roots. A URL with neither
is `http://`.

It is the browser's network with no browser around it: \man{netscape}{1}
and \man{lynx}{1} ask the same way.

**-i**
:    The answer's head before its body: the status line and the
     headers; with **-L**, every answer's.

**-L**
:    A redirection is followed, with a GET, ten at most.

**-v**
:    The request and the answer's head said on the standard error,
     a line each after `>` and `<`.

**-f**
:    An answer of 400 or more is a failure: no body, and said.

**-d** *data*
:    *Data* posted, as `application/x-www-form-urlencoded`.

**-o** *file*
:    The body written to *file*.

**--cacert** *file*
:    The roots trusted for `https://`, a PEM file, instead of the
     system's.

The flags have curl's letters, and also their long names
(`--include`, `--location`, `--verbose`, `--fail`, `--data`,
`--output`).

# EXAMPLES
```
curl -v https://example.com/
curl -L -o page.html http://localhost:8080/sub
```

# SEE ALSO
\man{lynx}{1}, \man{netscape}{1}

# DIAGNOSTICS
What failed is said on the standard error (a name with no address, a
connection refused, a certificate not trusted, too many
redirections), and the status is `curl`.

# BUGS
Less than curl: no HEAD, no header of one's own, no upload, no
cookie, HTTP/1.1 only; the body as the server sent it.
