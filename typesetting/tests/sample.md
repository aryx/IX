\title{sample}{7}
\newcommand{\ix}{**ix**}

# NAME
sample – the new format, each thing of it once

# DESCRIPTION
A paragraph is lines to a blank one, *italic*, _italic again_,
**bold**, `typed`, a [link's words](http://example.com) and
$n log n$, by \ix.\footnote{A footnote, said where it is.}
A snake_case name, a price of $5 and $10, 2 * 3, an escaped \*star\*,
a name not known: \n, and one with a text: \nothing{kept}.
See \ref{sec:more}, Figure \ref{fig:way} and \man{rc}{1}.\
A line ended by a backslash. \small{Small}, \big{big}, x\up{2}.

**-c**
:    A paragraph that hangs from its term, at column 5.
     Its second line.

     Its second paragraph.

*file* ...
:    Another.

- an item
  on two lines
- another, with a list in it
  1. one
  2. two

> Set in, as a quotation.

    set in by four columns: a program

```
let x = 1 in
	x + 1 (* a tab *)
```

```lines
lines as they are,
    with their **marks** read
```

| Test           | Plan 9 |   IRIX |
|:---------------|-------:|-------:|
| Context switch |  39 µs | 150 µs |
| `fork`         |   2 ms |   5 ms |

\figure[label=fig:way]{
```pic
box "readers"; arrow; box "Doc.t"; arrow; box "layout"
```
The way of a document.
}

\center{
In the middle.
}

## More \label{sec:more}
<div>HTML is said.</div>
![a picture](x.png) too.
