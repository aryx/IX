# Plan: new twists for t-ix's programs, one choice that deletes code and adds power

The author (2026-11-09): "it would be good to try to find more twist:
for the other tiny programs, and even invent new twist that are not
yet implemented but that would be great ideas simplifying the code
while at the same time making the program more powerful (like the use
of sha1 stamp in TinyBuildSystem)".

A **twist** (docs/tags.md, the section labels) is what a tiny program
does that its twin does not: an idea of its own, taken in the liberty
tiny/ has. The bar is tiny-build's stamps. One choice, a target's
stamp is the digest of its recipe and of its inputs' contents, deleted
timestamps' bugs and made four things free that mk cannot do: no false
rebuilds after a checkout, two writes in one second told apart, early
cutoff, and a rebuild when a recipe or one of its variables changes.
A twist must do both things: **delete code** (cases that disappear,
functions that go), and **add power** (a capability, or a classic
problem fixed). An idea that only adds power is a feature: those went
to the programs' `exercises:` sections. An idea that only deletes code
is a refactoring.

The twists t-ix already has are labelled `twist:` in their headers
(tiny-build's stamps, the file system that writes nothing in place,
the kernel's waiting calls as closures, the CPU's cache of decoded
words keyed by the word, the linker's sweep, the office's sheet with
no dependency graph...). This plan is for the ones not written yet.
They were found by reading each program's header and code against its
twin's (three analyses, 2026-11-09); their sizes are estimates until a
pilot measures them.

**Status: not started** (2026-11-09).

## The gate

Each twist starts as a pilot on one program, and is kept only if it
passes:

1. **Fewer lines**, by `make -C tiny loc`, counting what the twist adds.
2. **The new power works**, shown by a test that could not pass
   before.
3. **Nothing else changes**: the program's tests, `make -C
   tiny/TinyKernel check`, `make test`; output byte-identical where
   the twist does not mean to change it.
4. **It reads better**: the header's `twist:` can say it in a
   paragraph, as tiny-build's does.

A pilot that fails the gate is reverted, and the reason goes in this
file, so that it is not tried again for the same reason.

## The twists, in the order to try them

### 1. troff prints what the office draws

**Idea.** HTML (as SVG) and PDF are made from the office's view, the
TinyLibPlayground shapes it draws on the screen (`Rect`, `Words`,
`Group`, `Move`), instead of one renderer per kind of part per format.

**Deletes.** `text_html`, `sheet_html`, `drawing_html`, `paint_html`,
`chart_html` and the five matching `*_pdf` (TinyTroff.ml, about 250
lines), replaced by two small back ends from shapes.

**Gains.** What is printed is exactly what is on the screen; a new kind
of part prints with no change to troff.

**Costs.** The HTML loses its meaning (no `<table>`, no `<h1>`: the
text is drawn); plain text (`troff` with no option) keeps its own
renderers per part.

**Precedent.** NeXTSTEP's Display PostScript: one imaging model for
the screen and the printer.

### 2. One stack machine for tiny-c and tiny-ml

**Idea.** TinyMLMachine's IR and TinyC's lowered code are the same
stack machine kept in r1 to r11 (TinyML.mli says so: "the same as
TinyC's"). It is defined once, with one emitter that allocates the
registers; each compiler lowers to it, and what only ML needs
(allocation, tags, handlers, the value stack's slots) is a small
extension.

**Deletes.** One of the two emitters (TinyC/TinyCMachine.ml, 174
lines; much of TinyML/TinyMLMachine.ml, 482, is the same push, pop,
operator and jump), and the duplicated tables of operators.

**Gains.** Every improvement of the back end (constants folded into
immediates, a peephole, addressing modes) serves both compilers; one
emitter to port to another machine.

**Costs.** The calling conventions differ (C: arguments in memory, its
result in r13; ML: the value stack in r12, slots spilled at a call):
the shared part must leave them to each compiler, or the saving
shrinks to the operators and jumps (about 150 lines).

**Precedent.** Pascal-P's p-code (Wirth, 1973), one machine for many
front ends; UNCOL (1958), the idea.

### 3. Edge profiling: count jumps, not instructions

**Idea.** tiny-machine counts each control transfer taken (from pc,
to pc) instead of every instruction fetched; tiny-prof rebuilds the
counts per instruction from them (between jumps the code is straight),
and the `jal` edges are the call graph.

**Deletes.** The count at every fetch in the machine's hot loop (one
at a jump instead), and most of the profile file (an entry per edge,
not per address).

**Gains.** Who called whom, and a function's cost with its callees
(gprof's), which the flat profile cannot give: the hunt for the cost
of www's page-down had to infer that `ml_concat` was called from
TinyLibDraw. `-diff` keeps working, on edges.

**Costs.** Rebuilding the counts needs the code (the image, read
beside the map); traps and interrupts are edges too.

**Precedent.** Ball and Larus, "Optimally Profiling and Tracing
Programs" (POPL, 1992).

### 4. emacs and sam: one buffer, one command language

**Idea.** The screen editor's text is the line editor's buffer, and
emacs's search, `replace-string` and `goto-line` become sam commands
run on it (`M-x` takes a sam command); the keys stay for moving and
typing.

**Deletes.** emacs's own search and replace (its C-s handling, the
`Replace_from` and `Replace_to` answers), and one of the two models of
a text.

**Gains.** emacs gets structural regular expressions (`,x/re/c/.../`),
changes made in parallel, and undo through sam's inverse changes
(undo is in emacs's `dropped:` today).

**Costs.** sam's buffer is a string copied at each change, which its
own `modern:` says a screen editor cannot afford: the piece table
(TinyEditorLine's exercise) first, or emacs's line zipper kept for
typing and turned into the buffer at a command.

**Precedent.** sam itself (Pike, 1987), and acme: a screen and the
command language on one buffer.

### 5. Smaller ones

- **Tetris's well as rows of bits.** The well is a list of ints, a row
  each, and a piece's 16-bit rotation four row masks: a fit is four
  ANDs, a full row is a mask equal to all ones, filtered out; the
  cells' array and its copy on landing go (about 40 lines). Chess
  programs' bitboards.
- **www writes its pages as the office's text.** Each block is emitted
  as the office's styled text and filled by TinyOfficeText; TinyBrowser-
  Lines keeps only the tables. "Save page" gives an `.ixd` that office,
  emacs and troff open. Links need spans that can be clicked in the
  office's text. How much it deletes is the least sure of this list:
  the two fillers were not compared line by line.

## Considered and set aside

- **Restartable system calls (ITS's PCLSRing) instead of the waiting
  closures.** A call that must wait leaves the pc on its trap and is
  retried; a process's state is then only its frame. It would replace
  one twist with another, and the closures, which delete the kernel
  stacks and the lost wakeup, are the one to teach (Bawden, "PCLSRing:
  Keeping Process State Modular", 1993).
- **tiny-shell.** No twist at the bar was found: a block as a value
  (Tcl's, es's), `$status` as a list and `>` as a transaction are
  exercises in TinyShell.mli; the core choice, every value a list, is
  rc's.
- **tiny-vcs's objects marshalled.** Their bytes are their names: the
  readable text is what the header teaches (content addressing by
  hand), and a change of Marshal's format would rename every object.
  Postponed, not a twist.
