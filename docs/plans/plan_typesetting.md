# Plan: typesetting in ix: mini-troff and mini-man, one document in the middle, four ways to write it (man, ms, a new format, simple LaTeX) and three to show it (text, PDF, the new format) (`typesetting/`)

The author (2026-10-13): "what could be a mini-troff or a mini
typesetting system? On one side troff code is really ugly and the
worse program I think in principia and goken (because it was written
for unix, so is older than the other plan 9 programs), and the troff
language is also not super elegant. On the other side it's nice to
have man pages rendered in ascii and possibly pdf in m-ix, and it
would be nice to be able to transform in pdf the
~/principia/docs/articles/ few .ms documents there (with pics, graph,
eqn, etc.). We don't have though to handle all the dirty corner of
troff. Or maybe we should do something different and convert man
pages to a more modern format (markdown?) and the .ms too ? Not
sure."; then: "yes let's write the plan document; I would vote for
mini-troff still (and a mini-man program too). It would be nice also
that in addition to handling those man and ms documents, we come up
with a new modern format for document generation, a new syntax.
Ideally we could also have a mode to process simple latex documents
(e.g., the one used in principia) as a bonus."

The short answer: **not troff the engine: the documents.** The manual
and the papers are written in two macro packages, and what is ugly is
under them. `tmac.s` alone asks troff for 308 conditionals, 27
diversions, 16 environments and 11 traps; the 33 papers that use it
ask for a diversion twice and a trap twice. So mini-troff reads
`man` and `ms` with their macros as its primitives, into one small
document type, and everything else is on the other side of that type:

```
  man pages ──┐                                   ┌──▶ text   (mini-man, a terminal)
  .ms papers ─┤   roff lines ─┐                   │
              │   tbl, pic,   ├──▶  Doc.t ──▶ layout ──▶ PDF  (Pdf_write; mini-page reads it)
  new format ─┤   math        │      │            │
  LaTeX, .nw ─┘  ─────────────┘      │            └──▶ HTML   (later: mini-lynx, the site)
                                     └──▶ the new format, printed back
```

- **Four readers, one type.** Each input is turned into `Doc.t`
  (headings, paragraphs, tagged paragraphs, displays, tables,
  figures, footnotes; runs of text in a font). Nothing after the
  readers knows which one it was.
- **The new format is that type's own syntax**: Markdown's lines for
  what Markdown has, one form (`\name[options]{text}`, LaTeX's
  without TeX under it) for all it has not. And since the type can be
  printed back in it, **converting is a by-product**: `mini-troff -T
  doc rc.1` is the page in the new format. The first question ("or
  convert them to something modern?") need not be answered now: both.
- **The preprocessors are libraries**, not programs in a pipe: a
  table, a picture and an equation are each a value inside the
  document, read by whichever reader meets one. One table type for
  tbl, Markdown's `|` and LaTeX's `tabular`; one math type for eqn
  and for `$...$`; pic for pictures, to Playground shapes, which
  `Shape_render_pdf` already writes.
- **LaTeX as a bonus is the same shape**: a fourth reader, of the
  commands the books really use (215 different, 80 of them 98% of
  the uses), and of `.nw` itself rather than of what noweave makes of
  it.

About 4,000 lines of OCaml for all of it (an estimate, by part
below), where principia's troff, pic, eqn and tbl are 26,592 lines of
C and the two macro packages 2,133 of troff; grap (6,214) is not done:
no paper uses it.

Its numbers are `scripts/stats/typesetting_survey.sh`'s (run
2026-10-13, against principia at `6f2ea33f`, 2026-10-03).

**Status: stage 1 done on Linux** (2026-10-13): mini-troff and mini-man
write a manual page for a terminal, and principia's 553 pages come out
with troff's own lines, but 18 said by name. **Stage 2 done on Linux**
(2026-10-13): `-T pdf`, the 553 pages as 1,006 sheets, read back by
poppler with the words written. **Stage 3 done on Linux** (2026-10-13):
`-ms`, the papers without their tables, pictures and equations: 12 of
the 17 that have none are troff's word for word, the 5 others being
troff's accidents. **Stage 4 done on Linux** (2026-10-13): tables and
pictures; the papers' 11 pictures are all read, the 33 papers are 373
sheets (see Status at the end). Not done: stages 5 to 8.

## What there is

In principia (`typesetting/`, lines of .c .h .y .l):

| program | lines | here |
|---|---|---|
| troff (and nroff: one source) | 11,511 | not a twin: its two macro packages read directly |
| pic | 8,413 | a subset, a library |
| grap | 6,214 | not done: 0 `.G1` in the papers and the manual |
| eqn | 3,578 | a subset, a library |
| tbl | 3,090 | a subset, a library |
| htmlroff | 4,516 | a troff that writes HTML: the same idea as here, with the engine |
| ms2html | 2,641 | **the precedent**: `ms` read with no troff under it |
| troff2html | 991 | not done |
| deroff | 969 | the tests' "words" (below) are what it gives |
| page | 3,919 | mini-page is here already (`apps/page/`) |
| `tmac.s`, `tmac.an` | 1,601, 532 | not run: their macros are the readers' cases |

What the two packages ask of troff, and why they are not run:

| | lines | diversions | traps | environments | conditionals | registers set | macros |
|---|---|---|---|---|---|---|---|
| `tmac.an` | 532 | 3 | 4 | 2 | 108 | 38 | 23 |
| `tmac.s` | 1,601 | 27 | 11 | 16 | 308 | 135 | 108 |

To run them is to write troff: its registers and their arithmetic,
strings, conditionals on widths, text set aside and brought back
(keeps and footnotes are diversions), a second set of parameters for
the page's header (environments), and code run when the page reaches
a line (traps). That is n1.c to n5.c. Read as the readers' cases,
`.KS`/`.KE` is `Keep`, `.FS`/`.FE` is `Footnote`, and the page's
header is the layout's.

In ix (lines of .ml, of .mli):

| module | lines | what it gives this plan |
|---|---|---|
| `lib_graphics/pdf/Pdf_write` | 218, 148 | the file; **not text in a font yet** (its header says so) |
| `lib_graphics/fonts/Standard_widths` | 143, 31 | Times', Helvetica's and Courier's widths: lines can be broken as a printer would |
| `lib_playground/platforms/Shape_render_pdf` | 86, 27 | a picture's shapes as paths |
| `lib_graphics/pdf/Pdf_render` | 369, 130 | the file read back: `Pdf_render.text`, a page's words, for the tests |
| `apps/page/Pageview` | 290 | mini-page: the PDF shown, on Linux and on mini-9pi |
| `lib_graphics/images/Png`, `Jpeg` | 282, 449 | a book's screenshots (`Gif` is there too) |
| `apps/office/richtext/Page` | 333, 200 | greedy lines, justified, round boxes: **not reused** (decision 9) |
| `browsers/html/Line_mode` | 181, 74 | mini-lynx's text from a DOM: the HTML way, later |

And 164 Markdown files of ix's own (82,699 lines): the manuals, the
plans, the READMEs.

## What the documents ask

### The manual: 553 pages, 110,980 lines

76 different requests. The 50 most used:

```
12228 .B  9653 .I  6640 .IR  5179 .PP  3989 .TP  3292 .BR  3224 .SH  1505 .BI  845 .br  675 .IP
648 .EX  648 .EE  553 .TH  510 .L  452 .PD  355 .LR  342 .RB  333 .IB  325 .SS  312 .TF  203 .RI
191 .LP  181 .ta  179 .SM  147 .sp  144 .nf  115 .ti  112 .ft  93 .fi  64 .RS  64 .RE  64 .if
63 .HP  56 .PB  56 .ne  34 .in  30 .ns  16 .Ti  12 .RL  12 .EQ  12 .EN  11 .XX  10 .P  10 .de
8 .ig  8 .fq  8 .1C  7 .DT  7 .CT  7 .2C
```

Escapes: `\fP \fI \fL \fR \f2 \f1 \f5 \fB` (fonts), `\-`, `\&`, `\e`,
`\|`, `\^`, `\(em \(-> \(mu \(bu \(mi`, `\s±n`, `\u \d`, `\c`,
and **`\w` 226 times** (a width, in `.TP \w'...'u` and `.ta`: the one
piece of troff's arithmetic the pages really use), `\n` 42 (a
register read).

A table in 1 page, a picture in 1, equations in 4, a macro of its own
in 8, a conditional in 19 (64 `.if`, most of them `.if t`/`.if n`:
typesetter or terminal).

### The papers: 33 `.ms` files, 40,047 lines

Not only `docs/articles/`'s 11: the others are beside their programs
(`shells/docs/rc.ms`, `builders/docs/mk.ms`, ...). 116 different
requests; the most used are `.CW` 5,478, `.PP` 1,098, `.I` 939, `.LP`
709, `.P1`/`.P2` 618, `.SH` 251, `.IP` 244, `.NH` 211.

| | in all | in how many papers |
|---|---|---|
| tables (`.TS`) | 28 | 10 (`troff.ms` 14) |
| pictures (`.PS`) | 11 | 6 (`fossil` 4, `sam` 3) |
| equations (`.EQ`) | 7 | 4 (`auth` 4) |
| graphs (`.G1`) | 0 | 0 |
| PostScript pictures (`.BP`) | 8 | 2 (`troff.ms` 7) |
| macros of their own (`.de`) | 36 | 13 |
| conditionals | 23 | 9 |

troff's own requests, written in the papers between the macros:

```
.sp 121 in 19 papers    .br 86 in 19    .ta 41 in 8    .ft 37 in 7    .ps 30 in 9    .vs 24 in 7
.nr 21 in 5             .in 12 in 6     .ll 11 in 4    .ne 10 in 4    .if 13 in 5    .ie 4 in 4
.de 36 in 13            .ds 12 in 4     .tr 11 in 1    .nf 15 in 6    .fi 5 in 5     .ce 8 in 7
.ti 1 in 1              .di 2 in 1      .wh 1 in 1     .ch 1 in 1     .am 2 in 2     .so 1 in 1
```

So a state under the macros is needed (the font, the size, the
indent, the line's length, filling on or off, tab stops, a space, a
break), and `.de` with `\\$1`, `.ds`, `.nr` read back, `.if t`/`.if
n`. That is what "roff lines" is in the picture. What is refused is
the last row's `.di`, `.wh`, `.ch`, `.am`: 6 uses, 5 of them in
`troff.ms`, troff's own manual, which is the paper that will not be
whole (it also has 7 of the 8 PostScript pictures).

### The tables (the papers' 28 and the manual's)

Options: `center` 20, `box` 10, `tab` 1. Column letters: `c` 83, `l`
82, `|` 45, `w(...)` 15, `s` 12 (a cell across columns), `n` 10
(numbers aligned), `f` 10 and `p` 5 (font, size), `r` 2. Text blocks
`T{ ... T}` 47, `.T&` (the format changed part way) 23.

### The pictures: 5 `.pic` files (476 lines) and 11 `.PS`

857 lines of pic in all. What they say:

```
359 from  349 to  338 line  190 box  172 at  109 with  100 wid  95 Label:  77 .w  74 .nw  64 right
53 ht  49 .sw  49 fill  46 then  46 invis  43 [  39 .e  29 down  24 .s  23 .se  22 .n  21 move
20 rad  20 .ne  17 ljust  15 last  14 ellipse  14 arc  13 define  13 arrow  12 spline  10 up
7 cw  7 ccw  6 left  6 circle  4 dashed  4 copy  3 scale  2 dotted
```

Lines, boxes, places by name and by corner, blocks, macros. No `for`,
no `if`, no `sprintf`, no `sh`: the drawing half of pic, not its
programming half.

### The equations: 19 `.EQ`

7 in the papers, 12 in the manual. Ten of them are `delim $$`, which
turns on equations inside the lines: what is between the `$` is not
counted by the survey. Of the words of eqn, `sum`, `int`, `inf`,
`roman` once each. Small.

### The books: 68 `.nw` files, 630,767 lines, 22,684 code chunks

The prose between the chunks, less its comments: 139,141 lines. 215
different commands, the 80 most used being 26,587 of the 26,998 uses; among
them:

```
2949 \subsection  2322 \section  2040 \em  1874 \ref  1759 \l  1468 \verb  1330 \plan  1120 \item
1064 \t  938 \label  867 \subsection*  830 \n  587 \subsubsection  563 \book  484 \chapter
432 \sc  385 \emph  346 \unix  252 \cite  178 \furl  160 \principia  149 \bf  138 \input
126 \caption  119 \footnote  108 \midrule  105 \hlink  92 \centering  56 \texttt  45 \url
34 \includegraphics  22 \tableofcontents  21 \bibliography  20 \nowebindex  19 \part
```

Environments: `verbatim` 596, `itemize` 209, `vdiagram` 115 (a
verbatim in a frame), `figure` 103, `enumerate` 39, `center` 35,
`tabular` 25, `table*` 16, `verse` 12, `flushright` 12, `table` 6,
`minipage` 4, `quote` 3, `tikzpicture` 2, `thebibliography` 2.

- Classes: `report`, 12pt, 20 times; `twocolumn` twice; `article`
  once.
- Packages: noweb and syncweb's, xspace, verbatim, fancyvrb, url,
  hyperref, backref, booktabs, graphicx, multirow, tabularx, caption,
  tikz, amsmath, etoolbox, cleveref: each here for a command or two
  of the list above, none read as a package.
- The macros the books share (`docs/latex/`): 27 `\newcommand`, 12
  `\newif`, 2 `\def`, 1 environment defined. All of the simple kind:
  an abbreviation with arguments, a flag and its `\ifxxx ... \else
  ... \fi`.
- Math: 352 lines with a `$`, 2 displays. In them `\times` 47, `\to`
  46, `^` 46, `_` 19, `\text` 15, then Greek letters and relations a
  few times each, `\sqrt` once. No `\frac`.
- Pictures included: 15 PNG, 1 GIF, and 17 that the build makes (the
  lineage diagrams, by Perl and Graphviz).

So "simple LaTeX" is true of the books: sections, lists, verbatim,
figures, tables with rules, references, citations, footnotes, a table
of contents, an index. What is not simple is around it: the chunks
and their cross-references (noweb), the bibliography (BibTeX), two
columns, and the size (a book is hundreds of pages).

## The new format

**Proposed: Markdown's lines, and one form for all Markdown has
not.** Working name `ixdoc`, files `.ixd` (the name is open).

````
\title{mini-troff}{1}

# NAME
mini-troff, mini-man – typeset documents

# SYNOPSIS
**mini-troff** [ **-T** *dev* ] [ *file* ... ]

# DESCRIPTION
*Mini-troff* reads each *file* (see \ref{sec:formats}) and writes
its pages for *dev*.\footnote{The standard input if there is none.}

**-T** *dev*
:   Write for *dev*: `text`, `pdf` or `doc`.

\figure[label=fig:way]{
```pic
box "readers"; arrow; box "Doc.t"; arrow; box "layout"
```
The way of a document.
}

| Test           | Plan 9 |  IRIX |
|:---------------|-------:|------:|
| Context switch |  39 µs | 150 µs |

The cost is $n log n$ for \plan's sort.
````

- **Blocks are lines**: `#` headings, a blank line between
  paragraphs, `-` and `1.` lists, a fence for what is verbatim (its
  word says what reads it: `pic`, `eqn`, a language's name, nothing),
  `|` tables, `>` quotes, and a tagged paragraph as pandoc writes it
  (a term's line, then `:   ` and its text). The last is not
  Markdown's and is the one this plan needs most: `.TP` is the
  manual's fifth request, 3,989 uses.
- **Inlines**: `*emphasis*`, `**strong**`, `` `code` ``,
  `[text](url)`, `$math$`.
- **Everything else is `\name[options]{text}`**: `\ref`, `\label`,
  `\cite`, `\footnote`, `\figure`, `\title`, `\include`, `\sc`, and
  the reader's own (`\plan`). The text may be lines, with blocks in
  it. A document defines its own with `\newcommand{\plan}{Plan 9}`,
  LaTeX's, arguments `#1`: text put for text, nothing computed. No
  `\def` with patterns, no catcodes, no registers.

Why so, and not something wholly new:

- **ix's 164 Markdown files are then documents of this format**, or
  nearly (what Markdown they use that this does not read is to be
  counted, stage 5). The manuals and the READMEs come out as PDF and
  as a terminal's text by the same program as the man pages.
- **The one form is the author's hand already**: `\ref{sec:foo}`,
  `\book{Kernel}`, `\plan`, `\l`. And it is the LaTeX reader's
  command table, written once: the new format's `\ref` and LaTeX's
  are the same case.
- **Each thing in `Doc.t` has one spelling**, which is what makes the
  printer (`Doc.t` back to text) possible, and with it the
  converters.
- Not a programming language. Typst (2023) is the modern format
  nearest in look, and most of what it is is its scripting; a
  document here that needs to compute is made by a program that
  prints it.

The alternatives, for the author to choose between (decision 4): a
subset of Typst's syntax (`= Heading`, `#name(args)[text]`: regular
and new, reads none of ix's Markdown, and a "mini-typst" would
promise more than a subset); Scribble's and Pollen's `@name[...]{...}`
over plain paragraphs; or a syntax of ix's own from nothing.

## Decisions (proposed, to confirm)

1. **mini-troff is the program, and it is not troff's twin.** The
   name is the author's vote. It reads what troff's users wrote, not
   troff's language: no claim of the same bytes as troff's output (a
   typesetter's commands, by its fonts' width tables), which is what
   a mini-xxx elsewhere in ix promises. What is promised instead is
   below, "How it is checked": the same words in the same order, no
   request dropped without saying so, and a page that reads as the
   original's does.
2. **The macros are primitives; the packages are not run** (the
   table of `tmac.s` above). A small state for troff's own requests
   that the documents write (the 20-odd of the papers' list); `.di`,
   `.wh`, `.ch`, `.am`, `.ev` refused by name.
3. **A request that is not known is reported**, with its file and
   line, and counted at the end: never skipped in silence. The count
   is the measure of each stage.
4. **The new format** as proposed above, or one of the three others.
5. **tbl, pic and math are libraries read inside the readers**, not
   filters before them: `mini-troff rc.ms` and not `tbl | pic | eqn |
   troff`. The pipe is the Unix answer to a formatter too big to
   change; here a table is a constructor.
6. **Math is one tree with two syntaxes**, eqn's (`x sub i sup 2`,
   `a over b`) and TeX's (`x_i^2`, `\frac{a}{b}`), set by one small
   box layout. The new format's `$...$` reads TeX's; a `eqn` fence
   reads eqn's.
7. **Pictures are pic**, to Playground shapes: the papers' are, the
   new format's fence is, and it is a language worth having (the
   drawing half: no loops, no conditionals, `sh` never). tikz (2
   pictures) is not read; a box with its name stands for it. A
   PostScript picture (`.BP`, 8) the same: no PostScript here.
8. **Fonts are named, not carried**: Times for the text, Helvetica,
   Courier for `.CW`, by `Standard_widths`, in WinAnsi's encoding;
   Symbol for an arrow or a Greek letter. A real viewer shows the
   real fonts; mini-page shows its stroke letters at the same widths,
   so the lines are right there too. No font file read to write a
   document.
9. **A layout of its own**, not `richtext/Page`'s: that one is the
   office's (its folder, its `Rich.t` with a caret's offsets, one
   column with no pages) and what is common is forty lines of
   greedy filling. If the two come to look the same, factored then.
10. **Greedy lines first, as troff's; the rest separate and
    switchable**: hyphenation (Liang's patterns, TeX's: a small
    algorithm and a big table), lines broken by the paragraph
    (Knuth and Plass). Each behind an option, the simple way kept.
    Two columns will want hyphenation.
11. **The books are read as `.nw`, not as noweave's `.tex`**: a chunk
    is a display with its name, where it is defined and used; the
    woven file's `\nwbegincode` and the 976 lines of `noweb.sty`
    under it are not read. The author's `\l`, `\t`, `\n` are the
    `Macros.tex` cases (nothing, in a final book).
12. **LaTeX is a table of commands over a small expander**
    (`\newcommand`, `\newif`, `\input`, groups), and a command not in
    the table is decision 3's report. Not TeX: no `\def` with
    patterns, no `\catcode`, no `.sty` read.
13. **Parsers**: ocamlyacc for pic and for math (grammars, with
    precedence); by hand for roff's lines and tbl (line-oriented),
    for the new format (lines, then inlines) and for LaTeX (what an
    argument is depends on the definitions read on the way).
14. **One directory, `typesetting/`**, as principia's: `doc/` (the
    type, the layout, the writers), `roff/` (lines, man, ms, tbl),
    `pic/`, `math/`, `ixdoc/`, `latex/`, and the two programs.
    Compiled by OCaml 4.14 and by mini-ml; every file read through a
    capability.
15. **mini-man** finds a page by name and section and shows it as
    text; `mini-man -T pdf`. Which pages are in ix is open (below).

## The parts (lines: estimates, to be replaced by counts)

| part | what | lines |
|---|---|---|
| `Doc` | the type: blocks, inlines, a table, a figure | 80 |
| `Roff` | lines, escapes, `.de .ds .nr .if`, the state under the macros | 300 |
| `Man`, `Ms` | the two packages' macros as cases | 150, 300 |
| `Tbl` | the format lines, the cells, `T{ T}` | 150 |
| `Layout` | lines filled and justified, indents, tags, displays, tables, keeps, footnotes, pages and their headers; later two columns | 500 |
| `To_text` | a terminal's page | 120 |
| `To_pdf`, and text in `Pdf_write` | fonts named, words placed, links | 200 |
| `Pic` | the grammar, places and corners, to shapes | 450 |
| `Math` | the tree, eqn's and TeX's readers, boxes | 350 |
| `Ixdoc` | the new format read, and printed back | 400 |
| `Latex` | the expander, the table of commands, references in two passes | 600 |
| `Noweb`, `Bib` | chunks and their cross-references; a `.bib` read | 300 |
| the programs | mini-troff, mini-man | 120 |
| | | about 4,000 |

## How it is checked

- **Words.** A document's words in order, by this plan's text writer,
  against the same by a formatter that is not this one: `nroff -man`
  and `nroff -ms` of this machine (groff), goken's `troff`, `tbl`
  and `eqn` (built; its `pic` is not), `pdflatex` for a book. Line
  breaks and spaces are not compared; words lost, doubled or out of
  order are. For a PDF, the words are `Pdf_render.text`'s, read back
  from the file written.
- **Nothing dropped.** The count of decision 3, per corpus: 0 is the
  stage's end, or the list of what is left and why.
- **Looked at.** A page beside principia's own (`docs/articles/` has
  14 `.ps` and 2 `.pdf` kept beside the sources), by the author.
- **Recorded.** A few documents' text, and a few pages' pictures by
  their sums, as `apps/page/tests/`.

## The stages (each checked before the next)

1. **man to text: mini-man on Linux.** `Doc`, `Roff`, `Man`, the
   layout's paragraphs, `To_text`. The 553 pages: nothing dropped,
   the words nroff's.
2. **PDF.** Text in `Pdf_write`, `To_pdf`, pages with their headers
   and footers. A man page in a real viewer and in mini-page.
3. **ms, without tables or pictures**: the 19 papers that have
   neither, with their keeps and footnotes.
4. **Tables**, then **pictures**: all 33 papers but `troff.ms`'s
   leftovers.
5. **The new format**: read, printed back; a man page and a paper
   converted and read again give the same document; ix's own
   Markdown counted for what it does not read.
6. **Math**: the 19 equations, the books' 352 lines.
7. **LaTeX**: `docs/latex/About.nw` (37 lines) and the article
   (`docs/iwp9/iwp9.nw`), then one book in one column, then the
   bibliography, the index, two columns.
8. **m-ix**: built by mini-ml; mini-man on mini-9pi, pages in the
   image; a paper's PDF in mini-page there.

1 to 4 are the first message's wish; 5 is the second's; 6 and 7 the
bonus. HTML is after, if wanted.

## Open questions

- **The name of the new format**, and its extension.
- **Which man pages are ix's.** 51 of ix's 90 `mini-` programs have a
  page under their name in principia's sections 1 and 8 (`rc`, `mk`,
  `ed`, `sed`, `awk`, ...); 39 have not (`ml`, `cc`, `asm`, `ld`,
  `qemu`, `office`, `netscape`, ...; some are there under another
  name, `8c` for `cc`). Copy the 51, each said to be Plan 9's? Write
  the 39 in the new format? A page for mini-rc that describes rc is
  wrong wherever the twin is not exact.
- **A book's lineage diagrams** (17 pictures made by Perl and
  Graphviz at build time): left as boxes, read as a PDF made
  elsewhere (a PDF inside a PDF is not in `Pdf_write`), or laid out
  here (a graph's layout is another program).
- **How a book's size goes**: hundreds of pages through `Pdf_write`
  and back through mini-page, on a board. Not measured.
- **Characters**: WinAnsi and Symbol have the papers' `µ`, `½`, `→`;
  a character in neither (the papers on UTF and on names have
  examples in several scripts) needs a font carried. Counted at
  stage 3.
- **t-IX**: no tiny-troff proposed; t-IX is over its budget, and its
  manual is Markdown, which stage 5 would print.
- **troff.ms**: 14 tables, 11 macros, 7 PostScript pictures, the
  diversions and the trap. As far as it goes, or left out by name?
- **The screen without a file**: mini-page shows a PDF; a document's
  pages could also be Playground shapes drawn at once (a previewer).
  Not planned.

## Status

2026-10-13: this document and `scripts/stats/typesetting_survey.sh`.

**Stage 1, man to text, done on Linux** (2026-10-13; the author: "ok
let's start!"). `typesetting/troff/` (mini-troff: `Doc`, `Roff`,
`Man`, `Layout`, `To_text`, `CLI`) and `typesetting/man/` (mini-man):
1,600 lines by `wc`, the interfaces and their comments included (1,179
of `.ml`).

What it is checked by:

- `typesetting/tests/man.sh`: every page of principia's manual by
  mini-troff and by troff itself (goken's, as nroff, with Plan 9's
  `tmac.an`, not hyphenating, one page as long as the document; a
  table or an equation through goken's `tbl` and `eqn` first). Of
  553 pages, **535 are the same line for line** (runs of blank lines
  taken as one, a character that is not ASCII as a blank: goken's
  troff writes a blank for them, `bugs/goken.md` 36). The 18 others
  are those the script names, each with its reason:
  - 6 with a table, a picture or an equation (stages 4 and 6);
  - 3 with two columns (`.2C`, made by troff of a terminal's reverse
    line feeds; here the list stays in one);
  - 1 whose right edge is made even (`.ad`, `lp(8)`): not done;
  - 2 that set a text aside to measure it (`.di` with `\k`: `man(6)`,
    `ms(6)`): their table of requests is wrong here;
  - 7 where troff's output is an accident and mini-troff has what the
    page says (`bugs/goken.md` 37 and 38); `ms(6)` is one of them
    too.
  That the lines would be the same was not the plan's promise (the
  words in order was): it came from following each difference to
  troff's rule, and the rules are in `Man.mli`.
- `typesetting/tests/sample.sh`, in `make test` and `tests/lite.sh`:
  a page of ix's own with each macro and request the manual uses,
  its text recorded (the same as troff's, by hand once), a request
  not known, mini-man in a tree. Nothing outside the repository.
- Built by OCaml 4.14 (dune) and by mini-ml (mini-mk, arm64): the two
  programs write the same bytes, on the standard output and on the
  standard error, for the 553 pages. Built for Plan 9 on arm too
  (`mini-mk O=5 OS=plan9`); **not run there**.

What mini-troff says it does not know, in the 553 pages: 63 requests
in 33 pages. `.EQ` 12, `.TS` 1, `.PS` 1 (later stages); `.2C`/`.1C`
7 each; `.di` 4; and what no macro package defines, which troff
passes over in silence: `...` at a line's start 9, `.CT` 7, `.F` 3,
`.CW` 3, and seven others once or twice.

What changed from the plan:

- **One directory for the library, `typesetting/troff/`**, not
  `doc/` and `roff/` beside it (decision 14): mkprog builds a program
  from one directory, and mini-man links mini-troff's units from
  there. (Still so with the second reader, `Ms`: eleven modules.)
- **A terminal's characters**: `Doc` says a no-break space, a minus,
  a hyphen that is not a place to cut, where a word may be cut and
  where a sentence does not end by Unicode's own characters for them
  (U+00A0, U+2212, U+2011, U+00AD, U+200B, U+2060), not by
  constructors: a reader of another format has them for free.
- **`Layout` is already the one for PDF** in its shape (a width asked
  of the caller for each word, places in ens), but it has only met a
  terminal: lines of one height, no page.

Not done in stage 1: fonts shown on a terminal (bold, underline);
`mini-man` with ix's own pages (there are none: the open question
above); mini-9pi.

**Stage 2, PDF, done on Linux** (2026-10-13; the author: "let's commit
and move forward"). `mini-troff -T pdf page > page.pdf`, `mini-man -T
pdf`.

- `lib_graphics/pdf/Pdf_write`: text in a font the reader has
  (`Pdf_write.text`: "BT /F1 10 Tf x y Td (...) Tj ET", each font an
  object naming Times-Roman, Courier..., Windows' encoding; its unit
  test, read back by `Pdf_render.text`). 50 lines.
- `To_pdf` (new): the rows cut into sheets (8.5 by
  11 inches, 10 points on 12, lines of 6.5 inches: the manual's
  numbers), a header and a number on each; Times, its italic and bold,
  Courier, by `Standard_widths`; a minus a dash and the quotes
  quotation marks in Times, as troff's.
- `Layout`: a line's right edge made even (the room shared between
  its spaces); rows, with a space that may be less than a line (0.4
  between paragraphs on paper); **places in the writer's unit, whole
  numbers of it** (a thousandth of a point for paper).
- `Roff`, `Man`: a typesetter's units (a tenth of a point; `\w` by
  the fonts' widths), tmac.an's numbers for paper (3.6 ems where 5
  letters, 0.4 lines between paragraphs).

What it is checked by:

- `typesetting/tests/pdf.sh`: each of the 553 pages as a PDF file,
  read by poppler's `pdftotext`, which is not ix's: no complaint, and
  **551 have the words mini-troff says it wrote** (`-T words`), in
  order (blanks, hyphens, quotes and what is not ASCII aside; each
  sheet's header and number taken off). The 2 others have lines that
  go past the paper's right edge (`complete(2)`, `httpd(2)`: 9 lines
  not filled, longer than 6.5 inches), whose end no reader gives;
  mini-troff says so on the standard error, where troff says nothing.
  1,006 sheets.
- **The same bytes by OCaml and by mini-ml**, for the 553 files. It
  was not so at first: one place in one file was a hundredth of a
  point off, OCaml on arm64 doing a multiplication and an addition in
  one instruction, with one rounding, and mini-ml in two. Hence the
  whole units: sums of whole numbers are the same whatever computes
  them.
- `sample.sh` (in `make test`, `tests/lite.sh`): the sample page's PDF
  by its bytes' sum and its sheets, and its words.
- Seen: `tr(1)`, `bio(2)` and the sample page, drawn by poppler; and
  `tr(1)` by mini-page, ix's reader: the same lines, in its stroke
  letters. Its dash is a "?" there: the reader's letters have no en
  dash (not this plan's; a leftover for `Pdf_render`).

The characters the fonts have not (the open question above, counted):
**28 in 19 pages** of the manual, 22 different: Greek letters (π 3,
Δ 3, α 2, others once), `⋯` 2, arrows up and down, `√`, a hand, and
others once (`pdf.sh` prints them). Each is a "?" in the file and is said on the standard
error. An arrow to the right or the left, `≤`, `≥` and `≠` are
written by ASCII's way (`->`, `<=`). A font carried in the file, or
Symbol named beside Times, is what they need: not done.

Not done in stage 2: a line kept with the next (a heading can be a
sheet's last line: troff's man does no better); hyphenation (the
lines are made even without it, and some are loose); a tab in a line
that is filled is taken from the start of the line it is on, not from
where it was written as on a terminal; links; mini-9pi (built for it,
not run).

**Stage 3, the papers, done on Linux** (2026-10-13; the author away:
"I'll be back in a few hours"). `mini-troff -ms paper.ms`, `-T pdf`;
with neither `-man` nor `-ms`, a file with a `.TH` is a manual page
and any other a paper.

- `Fill` (new): what was the manual's reader's and
  is troff's own under any package, taken out of `Man`: the paragraph
  being filled, the requests a document writes between the macros
  (`.br .sp .nf .fi .in .ti .ta .ll .ce .ft .ps .tl`), the tree made
  from each paragraph's place. `Man` is on it, the same 535 pages
  line for line after as before.
- `Ms` (new): tmac.s's macros as cases. The title,
  the authors, the institution (`.TL .AU .AI .MH`), the abstract set
  in from both sides (`.AB .AE`), numbered headings and their numbers
  (`.NH`, `.SH`), paragraphs (`.PP .LP .IP .QP .RS .RE`), displays
  and programs (`.DS .DE .P1 .P2`), keeps (`.KS .KF .KE`), footnotes
  (`.FS .FE`), the fonts for a word or from here on (`.I .B .CW .R
  .SM .LG .NL`), tmac.s's registers that a paper sets (`\n(PI`,
  `\n(PD`).
- `Doc`: a paragraph's lines may be shorter than the others (an
  abstract, a quotation); a footnote; what is kept on one sheet; and
  the document says its own line's length and where its text is from
  its headings (a manual page's is to their right, a paper's is not),
  which the writers had as constants.
- `To_pdf`: a footnote at the foot of the sheet its mark is on, under
  a short rule, or of the next when there is no room; what is kept
  together goes to the next sheet if it does not fit. `To_text`: the
  footnotes at the document's end, under a rule, as troff's on one
  long page.

What it is checked by:

- `typesetting/tests/ms.sh`: each of principia's 33 papers by
  mini-troff and by goken's troff as nroff with Plan 9's tmac.s, on
  one page as long as the paper. troff's lines are not compared here
  (its right edge is even and its words hyphenated: ms asks for both
  on a terminal, which the manual does not), the words are, in order.
  16 papers have a table, a picture or an equation and are for
  stages 4 and 6. Of the 17 others, **12 are the same word for word**,
  and 5 are troff's accidents, mini-troff having what the paper says:
  a double quote in an argument of `.CW` moved or doubled (`.CW
  \&"." ,` written `.""`: `ape`, `lexnames`, `utf`, `8½`), and one
  closing parenthesis that troff does not write in `acid.ms` (not
  looked into).
- The sample paper (`tests/sample.ms`, in `sample.sh`): as text it has
  troff's own line breaks, seen side by side once; its PDF by its
  bytes' sum.
- The 33 papers as PDF: 357 sheets, the same bytes by OCaml and by
  mini-ml, read by poppler without a complaint. Seen: `names.ms`'s
  first two sheets and the sample paper, drawn by poppler.

What mini-troff says it does not know in the 33 papers (468 times):
the tables, pictures and equations (`.TS` 28, `.PS` 11, `.EQ` 7,
`.BP` 12); what the papers' own macros call and no package defines,
which troff passes over (`...` at a line's start 105, `.SP` 101,
`.NE` 92, `.Ti` 29, `.TP` 16); fonts it has not (`Jp` 10, `6` 9, `BI`
2); and `troff.ms`'s diversions and traps.

The characters the fonts have not, in the papers: Japanese and Greek
words (18 characters, 5 times each), and 8 others. 10 lines in 2 papers
go past the paper's right edge.

Not done in stage 3: two columns (`.2C`: one here); a figure that
floats to the next sheet's top while the text goes on (`.KF` is a
`.KS` here); a footnote's text a size smaller; a heading kept with
the paragraph after it; a paper's own header and footer (`.tl` in
its macros: written as a line); the cover sheets of Bell Labs'
memoranda. The interfaces' header comments say what each module is;
`Fill.mli` has troff's rules.

**Stage 4, its first half: tables, done on Linux** (2026-10-13).

- `Tbl` (new): what is between `.TS` and `.TE`. The
  options `center`, `box` and `tab(c)`; a row's format, a letter a
  column (`l r c n s`, `a` as `l`, `^` an empty cell), with `f` its
  font, `w` its width, `p` its size; `.T&`; a rule (`_`, `=`); a cell
  that is a text of several lines (`T{ ... T}`), read by the package
  itself since it has the package's macros in it (`Fill.aside`: the
  text being read put aside, another read, the first back).
- `Doc.Table`; `Layout.table`: each column as wide as its widest cell
  or as said, three ens between two, a number's point under the
  others', a cell across several columns, a text filled in its
  column, rules across (a row of the layout: `Rule`), the whole in
  the middle of the line if it says so and kept on one sheet.
  `To_text` draws a rule with hyphens, `To_pdf` with a line.
- Not kept: the lines down a table (`|`), a box's sides, a cell
  raised to the middle of two rows (`\^`: left empty, its text in
  the first row).

Checked: `ms.sh` gives the papers with a table to goken's `tbl`
first. Of the 22 papers with no picture and no equation: **14 the
same word for word, 1 the same letters in another order** (`ape.ms`:
the quotes of the accident below), 7 troff's accidents (a double
quote in an argument of `.CW`: `lexnames`, `utf`, `8½`, `rc`; `acid`'s
parenthesis; in `bootpc` a letter lost beside a line drawn with a
character that is not ASCII; in `lp` `\(en` written "en", Plan 9's
table for a terminal having no such dash: `bugs/goken.md` 36). The
manual's one page with a table (`tbl(1)`) has the same words as
troff's now (539 pages by the words, 535 by the lines). The 33
papers as PDF: 369 sheets, the same bytes by the two compilers, read
by poppler without a complaint. Seen: `mkfiles.ms`'s first sheet (a
table of texts) and `9.ms`'s table of numbers in its box.

**Stage 4, its second half: pictures, done on Linux** (2026-10-13).

- `Pic_lexer`, `Pic_parser.mly`, `Pic_ast`, `Pic`
  (new, 770 lines): the part of pic that draws. Objects (box, circle,
  ellipse, line, arrow, arc, spline, move, a text, a block between
  brackets with its own names), their sizes and places (`at`, `with
  .nw at`, `from`, `to`, `up 0.5`, `then`), arrowheads, `invis`, texts
  and where each is; places by name and corner (`A.ne`,
  `Block.Inner.s`, `last box`, `end of last line`), a point, a place
  and a move from it, a part of the way between two (`0.3 <A, B>`), a
  place's `x` and `y`; variables, `scale`, arithmetic; macros with
  arguments (`define`, in the lexer: text put for text) and `copy
  "file"`. The grammar by ocamlyacc and by mini-yacc, with no
  conflict (its two ambiguities said by a precedence).
- `Doc.Picture`: lines and words in inches; a circle, an arc and a
  spline are the short lines that look like them. `To_pdf` draws
  them; `To_text` writes the picture's words, a terminal having no
  lines.
- A document reads the files it names (`.PS <file`, `copy`, `.so`),
  through the program's capability to open one.
- Not drawn: dashes and dots (the line is solid), fills (the box is
  empty), a line cut at a circle's edge (`chop`). Not run: pic's
  programs (`for`, `if`, `sprintf`, `sh`), which no paper has.

Checked: **the 11 pictures of the papers are all read**, 5 from files
(`network.pic`, `transition.pic`, sam's three figures). Seen, drawn by
poppler: the plumber's figure (ellipses, splines, arrowheads), IL's
state machine (arcs between circles, their labels), Fossil's
tree of blocks (a macro of three arguments called a dozen times),
the security architecture, and the sample paper's. Not compared with
pic's own drawing: goken's pic is not built, and a picture's check
is the eye; a figure's texts that are equations (`$F sub T#`,
`auth.ms`) are written as they are until stage 6. `net.ms`'s figure
is not pic but what pic made of it (`.so tree.pout`): not read, and
said. The 33 papers: 373 sheets, the same bytes by the two compilers
(the picture's sines and square roots included), read by poppler
without a complaint. The sample paper has a table and a picture;
`sample.sh` on the two builds.

### Stage 5: the new format (decision 4: Markdown's lines and `\name[options]{text}`, in plain `.md` and in `.ixd`)

The author chose it over an outline of named things (indentation as
the only structure, references by a thing's own name, marks that say
what and not how), which was the other contender: "ok let's do A and
let's use plain .md (and also allow .ixd)". Two of the outline's
ideas are kept where they cost nothing: `\man{rc}{1}` says what a
word is, and a hanging paragraph's body is at the column where its
text is written, so that the source looks like the page.

- `Ixdoc` (new, 801 lines of `.ml`, twice the estimate: the writer
  back is 250 of them): the reader, by hand (lines, then a line's
  marks), and the writer of any `Doc.t` in the format.
  `mini-troff file.md`, `-md`, and `-T md` for the way back:
  `mini-troff -T md tr.1 > tr.md` converts a manual page. Its
  interface says the whole format.
- What differs from the proposal: a blank line is a space and no
  blank line is none (a closed-up list is troff's `.PD 0`); a
  hanging paragraph's width is its text's column (`:    ` is 5), a
  list being the same thing with a bullet for term; three fences
  (lines as they are, `pic`, and `lines` whose marks are read); a
  command that starts a line and ends it with `{` has lines to a `}`
  alone; `\ref` of a section writes its title (headings have no
  numbers), of a figure its number; a name not known is said when it
  has a text and written as it is when it has none (`\n` in a
  sentence about C); `$...$` is italic until stage 6.
- **Written and read again** (`typesetting/tests/md.sh`): each of
  the 553 pages written in the format and read back has the same
  words in the same order, 553 of 553; 264 the same lines (the
  others: a hanging paragraph's width that is not a whole number of
  columns, mostly); 551 are written again the same bytes. The 33
  papers: 31 the same words, the 2 others the same words in another
  order (a table wider than the line whose columns' widths tbl was
  told: the format has no way to say them); none the same lines (a
  paragraph's first line set in is not said either).
- **ix's own Markdown**: of the 164 files (50,606 lines), 161 are
  read with nothing said; the 3 others have a picture from a file
  (8, said, their words kept). Each is made a PDF file. What they
  use that Markdown has and this has not: nothing was found but
  those pictures (no HTML, no link kept apart, no heading by
  underline); 125 blocks set in by four columns are read as
  programs. Their box-drawing characters are not in the PDF's fonts.
- The two builds write the same bytes (text, the format, PDF) on the
  164 files and on 140 of the converted pages; `sample.md` in
  `sample.sh`, on the two builds; built for Plan 9 on arm.

Left of the format: cross-references to another file, a table's
widths and rules, the bibliography (in the new format `\cite` still writes its key:
stage 7's is LaTeX's), equations (stage 6).

### Stage 7: LaTeX, before stage 6 (the author: "Let's postpone equation. I'm not an heavy math user. Let's do stage 7 instead.")

`Latex` and `Bib` (`typesetting/troff/latex/`; 1,290 lines of `.ml`,
1,415 with the interfaces: the plan said 900 for `Latex`, `Noweb` and
`Bib`; the chunks are in `Latex`, 80 lines of it, and the tables of
commands are a third of the file). Decisions 11 and 12 as written: the
`.nw` is read, not noweave's `.tex`; a table of commands over a small
expander (`\newcommand`, `\def` without a pattern, `\newenvironment`,
`\newif` and its conditionals, `\input`, groups), and a command not in
the table is said once with its line. A file named `.tex` or `.nw` is
LaTeX, `-latex` says it; a file a document names is looked for as
named, then from where the document is (pdflatex runs there).

What was decided on the way:

- **A chunk has a number**, in the file's order, and its name is
  written with the number of its first definition, here and where
  another chunk names it; the first definition says where it is used
  and where it goes on: `<function addrule 41>=   (used in 12; more in
  44)`. noweb says it with a page and a letter (`12b`); a page is not
  known to a reader, only to the layout. `\nowebindex` is the chunks
  by name.
- **Two readings**, the first for what is named before it is there:
  `\ref`, the table of contents, a chunk used above its definition,
  the citations' numbers. A book is read twice in a second.
- **The bibliography** is one style: the entries cited, in the order
  they are, numbered; authors, title in italic, where, year, note.
  BibTeX's styles are programs (plain.bst: 1,100 lines); not read.
- **syncweb's marks**: `#include "file.nw"` at a line's start is the
  file; a line that starts with `\l`, `\t` or `\n` is the author's
  note and is not written (Macros.tex's final book); `[<name>]` is a
  name in the typed font.
- **Mathematics as far as words go**, since stage 6 is postponed:
  letters in italic, what is raised and lowered a size smaller, the
  symbols WinAnsi has, a word for the others (`alpha`, `<=`). The
  books have no fraction.
- **A table whose cells are blocks** (the article's Table 2: a
  minipage of verbatim text beside a minipage of chunks) is its cells
  one after the other: a cell of `Doc.t` is a line of text.
- **One column**; `\includegraphics` writes the file's name and is
  said (34 in the books: `Pdf_write` has no picture from a file);
  tikz is said (2); `\pageref` is said (1).

What it is checked by, `typesetting/tests/latex.sh`: each of
principia's 21 documents (the `.nw` files with a `\documentclass`: 20
books and the article) as a PDF file, and its words against
pdflatex's where principia's build left a PDF file beside it (20 of
the 21), the words of three letters and more that poppler reads in
each:

- **All 21 are made: 8,364 sheets** (pdflatex's Make: 213; here 197),
  in 88 seconds with the comparison, a book in one to four seconds
  (the kernel: 49,062 lines, 1,050 sheets, 4.2 s).
- **Of pdflatex's words, 91 to 99 in 100 are ours**, by book
  (Compiler and Network 91, Utilities and Network_apps 99, the
  article 98). What is not: pdflatex's files are of an earlier day's
  source, noweb's "Uses" and the pages it cites, the references'
  labels.
- **What is said, all books: 103 lines.** 34 pictures from files, 23
  characters the fonts have not (Greek, Czech letters in the browser's
  tables of characters), 17 files with lines past the right edge
  (code of more than 90 letters), 12 `\ref` to a label that is not
  there and 9 `\cite` to a key that is not (the books' own: a
  `chap:utulities`, a `Machine` book not in `Principia.bib`), 2 files
  not found (the Scheme book names `../docs/latex` from two
  directories down), 2 tikz pictures, 2 commands not known.

Three mistakes of the reader that the books found, each in one
character: a `%` inside `[[...]]` taken for a comment by what looks
for an argument's end (mk's `%` rules); `\item [['%']]` read as
`\item`'s optional argument; a `&` after `\end{minipage}` not seen as
a cell's end. `sample.nw` and `sample.bib` (new) have each thing once,
in `sample.sh`.

Compiled by mini-ml (one change: `for _ = ...` is not its OCaml): the
same bytes as OCaml's build, text and PDF, on the article and four
books; mini-ml's program is seven times slower (Make: 7.4 s for 1.0).
Built for Plan 9 on arm, not run there.

Not done: two columns (the template's `twocolumn`: the books are set
in one), pictures from files, an index of identifiers (syncweb's
`defs_and_uses`), page numbers in the table of contents and in a
chunk's name, hyphenation.

### The folders

`typesetting/troff/` had 30 files: its parts are in folders, as
`apps/office`'s (folders only, one library): `doc/` (Doc, Layout,
To_text, To_pdf), `roff/` (Roff, Fill, Man, Ms, Tbl), `pic/`,
`ixdoc/`, `latex/`; CLI and Main at the top. Decision 14's names, inside the
program's directory and not beside it.

All of typesetting/: 6,073 lines with the interfaces and their
comments. Of the plan's stages, 1 to 5 and 7 are done on Linux; left:
equations (6, postponed by the author), m-ix (8: built for Plan 9 on
arm, not run).

Next: stage 8, m-ix; or stage 6.
