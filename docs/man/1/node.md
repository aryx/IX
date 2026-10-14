\title{node}{1}

# NAME
node – JavaScript, outside a page

# SYNOPSIS
**node** \[ *file.js* | **-e** *text* ]

# DESCRIPTION
*Node* runs JavaScript with no page around it: the engine that
\man{netscape}{1} runs a page's scripts with, given a terminal instead.
`console.log` writes on the standard output.

*file.js*
:    Its statements run.

**-e** *text*
:    The text's statements run.

With neither, each line of the standard input is run, and its value
written, until the input ends; on a terminal, after a prompt `>`. The
definitions of a line are there for the lines after it.

The language is today's, most of it: `let` and `const`, classes, arrow
functions, destructuring, the spread, generators, `async` and `await`,
promises, `Map`, `Set`, `Proxy`, regular expressions, JSON. What the
host gives is the standard output and the clock, no more: a file is not
read by a script and nothing is fetched.

# EXAMPLES
```
node -e 'console.log(6 * 7)'
echo '[1, 2, 3].map(x => x * x)' | node
node fib.js
```

# SEE ALSO
\man{netscape}{1}

# DIAGNOSTICS
A script that ends by an error says it on the standard error, with its
line, and the status is 1.

# BUGS
An `import` finds no module and says nothing: the names it would have
given are not defined.
