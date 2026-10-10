# Header comments, and the tags in them

ix is read to learn how an operating system and its tools are made.
The code says how; a module's **header comment** says the rest: what
the module is, how it works on a small example drawn or worked out,
where the idea came from, what the others do, what to read. This file
says where that comment is, what goes in it, and how the paragraphs
that are around the module rather than the module's own are marked.

The convention is mini-chrome's (`~/github/mini-chrome/docs/tags.md`)
and the playground's (`~/playground/libs/**/*.mli`); the tags'
vocabulary is principia-softwarica's (`docs/latex/Tags.tex` there),
where the same tags are `%`-comments in the `.nw` sources and are to
become boxes in the books. Here they are words in an OCaml comment.

## Where the header comment is

| The file | Its header comment |
|---|---|
| `X.mli` | the first thing in the file: no author's line, no copyright (an interface is not copyrightable) |
| `X.ml` with an `X.mli` | `(* See X.mli *)`, after the two lines |
| `X.ml` without one (a program in one file, `utilities/files/Cat.ml`; a module that is its types, `shell/Ast.ml`) | the comment after the two lines |
| a program in several files | its `CLI.mli`'s: the program as a whole, its history, then the command line. Its modules' interfaces each have their own part of the story |

An `.ml` starts with the author's line and the copyright's, then a
blank line, then the header comment, a comment of its own:

```ocaml
(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-cat: Plan 9's cat (principia's utilities/files/cat.c) ...
```

`scripts/stats/header_shape.py` puts a file in that shape
(`short_header.py` first, for the nine lines of a license). A file
copied from the playground, principia or goken keeps its line of
origin (`(* ix: the author's playground's libs/compression/Lzw.mli
... *)`) right after the header comment, a comment of its own.

## What goes in it

In this order, each only when there is something to say:

1. **One sentence**: what the module is, with the name a reader
   would search for ("Huffman codes: short codes for common symbols,
   rebuilt from their lengths alone").
2. **How it works**, on the smallest example that shows it: a diagram
   in ASCII (a tree, a layout of bytes, who calls whom), a session, a
   table worked out by hand. The tests check those examples: change
   both together.
3. **Where it stands in the whole system**: ix is one system, from
   the assembler to the browser, and the point of reading it is to
   see it whole. Who calls the module and what it calls, the same
   idea met elsewhere in the tree (`Huffman.mli` for deflate and for
   JPEG; threaded code in rc's C and in `languages/forth`), the
   kernel's side of what a program asks (`shell/Process.mli`'s fork
   to the kernel's). By the module's name, not its path.
4. **What is ours**: the choices made here, what is left out and what
   it costs, where it differs from the program it follows.
5. **The tagged paragraphs** (below): the history, the others, the
   words.
6. **References**: the paper, the manual page, the RFC, the file of
   principia or Plan 9 it follows, with the year, and a word on what
   each is read for. A paper belongs to the module that implements
   it: cited where its idea is in the code, not in a list apart.

Only what is certain: a date or a name left out rather than guessed,
and "(from memory)" after a citation not checked against its source.
A comment copied from mini-chrome or the playground is kept whole
and may be extended; it is not cut to fit.

A module of twenty lines whose name says it all (a printer, a table)
needs its sentence and no more. The long comments are for the
modules with an idea in them.

## How a tag is written

On a line of its own, before the paragraph it is about, with the
comment's indentation and a colon:

```ocaml
(* Globbing: *, ? and [...] against file names.
 *
 * A word keeps, as it is expanded, which of its characters were
 * quoted ...
 *
 * cs-history:
 * In the first Unix shells the shell did not expand a * at all: it
 * ran /etc/glob, a program, with the command and its arguments ...
 *
 * References: ...
```

(In a comment whose lines do not start with ` * `, the tag's line
does not either.) The tag holds for that paragraph, to the next blank
line. A history of several paragraphs has the tag before each. A
paragraph has one tag at most, its main kind. A fact in passing
("David Huffman's algorithm (1952)") inside a paragraph that explains
the module is not tagged: a tagged paragraph is one that could be put
in a box, or left out, whole.

There is no tag for who wrote a paragraph (principia's `%claude:`):
the file's first line says who wrote the file.

## The tags

The test, as in principia: without the paragraph, would the reader
still understand the module? If yes, it can be tagged; if no, it is
the module's own, and has no tag.

| Tag | What the paragraph is | Example here |
|---|---|---|
| `cs-history:` | where it came from: who made it, when, where, and why it mattered then | `/etc/glob`, a program (`shell/Glob.mli`); dc, older than C (`utilities/calc/dc/CLI.mli`) |
| `modern:` | how today's systems do it, where we do the simple thing | zlib's lookup tables, where we read a bit at a time (`lib_compression/Huffman.mli`) |
| `others:` | how other systems do the same thing: another shell, another kernel, another way | fish and zsh say "no match" (`shell/Glob.mli`) |
| `evolution:` | how a thing changed over the years, from its invention to now | the shell from Thompson's to rc (`shell/CLI.mli`) |
| `design:` | a principle of design the module shows, true beyond it | input never scanned twice (`shell/Word.mli`) |
| `terminology:` | words that are confused, told apart | deflate, zlib and gzip (`lib_compression/Zlib.mli`) |
| `why-win:` | why this one prevailed over its rivals | deflate over LZW (`lib_compression/Zlib.mli`) |
| `comeback:` | an idea invented, set aside, and back in another form | |
| `road-not-taken:` | an idea of merit that history passed by | threaded code for a shell (`shell/Eval.mli`) |
| `reframe:` | the thing seen as another | the shell, an ordinary program (`shell/Process.mli`) |
| `wib:` | worse is better: a deliberate simplification, and what it costs | cat with no option (`utilities/files/Cat.ml`) |
| `why-study:` | why this old or small thing is worth reading | |
| `plan9-is-cleaner:` | what Plan 9 made simpler than Unix, seen in this module | /env, a file a variable (`shell/Env.mli`); a directory made by create (`utilities/files/Mkdir.ml`) |

The last one is principia's and not mini-chrome's: ix follows Plan 9.

## Counting them

m-ix and t-ix are numbers to keep small (`docs/loc.md`), and a number
to keep small must not be a reason to teach less: `make loc` prints
the two again without the header comments, tagged or not, and those
are the numbers of the log. It also says how many lines the header
comments are and, of m-ix's, how many are under each tag
(`scripts/stats/loc.py`).

Only the header comment is left out. A comment on a function or a
type, in the `.mli` or the `.ml`, is counted as before.
