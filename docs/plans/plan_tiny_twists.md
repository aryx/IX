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

**Status: not started** (2026-11-09); a second search, 2026-11-10, for the programs without a twist: four candidates below the bar (6 to 9), the rest set aside with its reasons.

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

## The second search (2026-11-10)

For the programs with no `twist:` yet (the author: "let's try to find
candidates for the programs without one yet"), three readings against
the twins: the shell, sam, emacs and trace; play, temp, tiny-cpu,
tiny-machine and the assembler; tiny-c, tiny-ml and the libraries
(Draw, Regex, System, Machine). None reached tiny-build's bar; four
candidates are below it, each to prove its deletion in a pilot.

### 6. sam: a line is a match

**Idea.** sam runs `x` with no pattern as `x/.*\n/` (its linex): every
line address (`3`, `+`, `-`, the newline command) becomes the n-th match
of that line pattern, which a command changes.

**Deletes.** `lineaddr` (about 38 lines) and the `Lines` case of the
loop (11), for an n-th match over `Regex.search` and `search_back`
(about 15): about 30 lines.

**Gains.** A "line" a paragraph, a record, a function: `3p`, `.+1`, a
bare `x` in those units; awk's RS in sam's language.

**Costs.** sam's corner cases (line 0, a range ending mid-line, a last
line without its newline), which the tests diff against `sam -d`; the
matcher slower than a loop over characters for `5000p`.

**Precedent.** sam's linex; awk's RS; Pike, "Structural Regular
Expressions" (1987).

### 7. trace: the kernel writes each call's line

**Idea.** The table of the arguments' kinds goes into the kernel, which
copies a path or the bytes given at the call and the bytes filled at
the return into the trace's line: the process is not stopped.

**Deletes.** In trace, `bytes`, `path`'s 64-byte loop, `fills`,
`pending`, the matching of a call with its return (about 40 of 213
lines); in the kernel, the call and return stops (about 25), less a
formatter (about 25).

**Gains.** Tracing at about full speed (today two stops and a read per
byte at each call), and the traced program scheduled as when it is
not: strace's Heisenbug, a race that tracing hides, gone.

**Costs.** Against trace's own design ("the kernel keeps nothing of
the call and decodes nothing"); a slow reader means a buffer without
end, or the process stopped when it is full.

**Precedent.** Plan 9's kernel formats ratrace's lines
(port/syscallfmt.c); DTrace's syscall provider.

### 8. tiny-machine: one agenda for what happens at a time

**Idea.** Time is instructions, so what is not one happens at a known
count: a session's event, a packet's landing, the timer, the peer's
waking, the host's polls. One list ordered by time, an entry a time and
a closure (`at mc after f`), in place of four mechanisms (`events`,
`flying`, `timecmp`'s checks, the loop's polls) and of the peer's empty
packet that means "wake me".

**Deletes.** About 30 to 40 lines (tick's events and landing, `landed`,
`net_give`'s place, most of `calm`, the empty packet's cases), not
measured.

**Gains.** A device that answers N instructions later in a line: the
header's slow disk exercise, a slow console, a packet's latency.

**Costs.** `calm` stays for the registers' writes; closures make the
machine's state harder to save; the power is mostly exercises made
cheap.

**Precedent.** SIMULA 67's event list; gem5's EventQueue; QEMU's timers
with icount.

### 9. emacs: the text a snapshot

**Idea.** Before a key that changes the text, a shallow copy of its
record: it shares every line, the editor never changing a string.
Undo puts the last back; "modified" is the lines compared with those
saved (`==`, then `=`), not a flag.

**Deletes.** The `modified` field and its 9 updates (about 10 lines),
about as many back for undo: gate 1 in doubt.

**Gains.** Undo (in `dropped:` today); a text typed then erased, or
undone to its save, is unmodified again.

**Costs.** A record per key (a run of letters could share one); a
comparison of the lines at each key, for the mode line.

**Precedent.** The office's and mini-office's undo, earlier texts;
Yi's and Xi's persistent buffers.

### Found on the way, fixed (not twists)

- TinyLibRegex's `search` made a memo per start: a search that failed
  was quadratic (1.25 s for `(a*)*b` on 3,000 letters, bytecode, where
  `matches` took none). One memo for all the starts, as `matches` had;
  `matches` a search.
- tiny-c folded constants only where a number was needed (const_expr)
  and in unary minus: `int x = 2*3;` was refused, `p + 1` a li, a li
  and a mul. The tree folds them as it is built.

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
- **tiny-shell, again (2026-11-10).** `$status` as a list (per stage)
  changes what it prints, which the tests compare with 9base rc's;
  blocks as values (es) keep rc's syntax for the same tests, the cases
  moved, not gone; glob flags for the `\000` escapes only re-encode.
- **play, temp, tiny-cpu.** Too small to delete much: a sound as a
  function of time is what `piece` is; a table of scales for temp
  folds two cases of 64 lines; tiny-cpu is a command line.
- **The assembler: one table of instruction shapes** (the NJ
  Machine-Code Toolkit, TableGen), encode, decode, print and parse
  derived from it. The code is half tables already (`alus`, `cmps`,
  `named`); 30 to 50 lines over TinyLibMachine and TinyMachineDevices,
  and its power, print and parse agreeing, a law the tests check.
- **tiny-c.** Constants folded in the tree: 5c folds them too (a fix,
  above, not a twist); a call's types checked at the link: 5c's -T;
  more than 12 deep spilled: a feature.
- **tiny-ml.** Eval/apply with the arity in the closure: ocamlopt's
  caml_applyN; the value stack as the stack machine's: every push a
  store, against making the core fast, and against twist 2; the
  interface inside the object (Go's export data): nothing deleted.
- **The libraries.** Regex's memoized backtracker is its design, and
  libregexp is linear too; Draw's messages as a variant decoded once:
  a refactoring, the power (a drawing saved and replayed) already
  there, its messages being bytes; System's spawn with descriptor
  changes: the shell needs fork for a block in a pipeline; Machine's
  objects of lines not encoded, encoded at the link: 5c and 5l's way.
