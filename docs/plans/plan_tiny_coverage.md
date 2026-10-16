# Plan: what t-ix needs so that every part of m-ix has a tiny twin

The author (2026-10-16): "what do we need to add to t-ix so it matches
m-ix ?"; of plan_tiny_gaps.md, which looks inside each tiny program for
what a person misses: "I don't think this plan document address my
question"; then "yes, write plan_tiny_coverage.md".

**Step 1 started (2026-10-16)**: grep and sort are in tiny-utils (the
author: "let's start with the filter: grep, sort, and later on an app
like a spreadsheet and word document; ideally we could do a
tiny-office but it seems difficult"). uniq, tr and sed are left of
3.1. Section 5 says what was found.

This plan asks a different question from plan_tiny_gaps.md. That one
took each tiny program and asked what it lets a person do. This one
takes each part of m-ix and asks whether t-ix has a twin of it: a tiny
program, library or part of tiny-kernel that keeps its idea.

The numbers are lines of code from `scripts/stats/loc.py -v`
(2026-10-16, without the tests). The sizes of what is planned are
guesses.

## 1. Where t-ix stands

m-ix is 185,000 lines (the mini programs and the libraries) and t-ix is
24,000. Most of m-ix already has a twin; `tiny/README.md`'s table says
which, in its "its twin" column.

| m-ix | lines | its tiny twin |
|---|---:|---|
| `builder/` | 2,525 | `TinyBuildSystem.ml` (tiny-build) |
| `shell/` | 2,359 | `TinyShell.ml` (tiny-shell, and tiny-kernel's rc) |
| `editors/ed/`, `editors/emacs/` | 4,921 | `TinyEditorLine.ml`, `TinyEditorScreen.ml` |
| `assembler/`, `linker/` | 4,174 | `TinyAssembler.ml` (and `TinyLinker.ml`, which says why there is no linker) |
| `languages/c/`, `languages/ml/` | 15,432 | `TinyC.ml`, `TinyML.ml` |
| `database/` | 3,084 | `TinyDatabase.ml` |
| `version_control/` | 4,961 | `TinyVCS.ml` |
| `machine/` | 5,029 | `TinyCPUArm.ml`, and `TinyCPU.ml` for a machine of our own |
| `raspberry/` | 5,609 | `TinyMachine.ml` and `TinyMachine/` |
| `kernels/9pi/`, `kernels/lib_machine/` | 20,803 | `TinyKernel.ml` and `TinyKernel/` |
| `windows/` | 1,554 | `TinyWindows.ml` |
| `browsers/` | 28,826 | `TinyBrowser.ml` |
| `lib_graphics/`, `lib_networking/` | about 12,000 | `TinyKernelGraphics.ml`, `TinyKernelNetwork.ml` |
| `lib_gui/`, `lib_playground/` | 13,404 | `TinyLibGUI.ml`, `TinyLibPlayground.ml` |
| `lib_core/` | 19,693 | `TinyLibHost/`, and tiny-ml's prelude and `TinyLibStd.ml` |
| `utilities/files`, `misc`, `pipe`, `byte`, `compare` | 1,748 | `TinyUtilities.ml` (tiny-utils) |

Some twins drop a large part of m-ix on purpose, as their headers say,
and that is not a gap: TinyBrowser has no style sheets and no
JavaScript (10,766 lines of `browsers/javascript/`): it keeps no
document tree for a script to change. And tiny-machine has
none of the Raspberry Pi's USB, storage or sound (`raspberry/usb/`,
`storage/`, `sound/`), since its devices are designed, not copied.

What needs no twin:

- `kernels/dos/`, `kernels/l4/`, `kernels/xen/` and `languages/dotnet/`
  hold only survey scripts, no code.
- The languages of the playground (scheme, pascal, prolog, datalog,
  forth, smalltalk), the other systems of `kernels/` (xv6, oberon,
  singularity, squeak) and what else `loc.py`'s APART lists are not
  counted in m-ix: ix is the same without them.
- `lib_compression/` and `lib_crypto/` are used by tiny-vcs as they
  are: zlib and SHA-1 are what git's objects are, not an idea to make
  smaller.
- `games/`, `lib_code/`, `lib_juice/`, `lib_physics/` are counted under
  "other", not in m-ix. (tiny-kernel has tetris anyway.)

## 2. What is missing

Five parts of m-ix have no twin, and one has half of one:

| m-ix | lines | the twin to write | its cost |
|---|---:|---|---|
| `utilities/text`, `time`, `process`, `calc`, `namespace` | 6,924 | more of tiny-utils: grep, sort, uniq, tr, sed; then date, ps, kill, hoc | low for the filters; date, ps and kill need kernel calls; namespace needs bind, which tiny-kernel does not have |
| `generators/` (lex, yacc) | 1,593 | tiny-yacc, tiny-lex | low |
| `typesetting/` (troff, man) | 6,808 | tiny-troff | medium |
| `apps/` (office, music, page) | 10,145 | applications of tiny-kernel, `TinyAppXxx.ml` | medium, one at a time |
| `lib_audio/` | 9,057 | a sound device in tiny-machine, and a tiny synthesizer | high: a device to design first |
| `networking/` (curl, httpd, timesync) | 423 | probably none (see 3.6) | none |

## 3. Each missing part

### 3.1 The rest of the utilities

- **m-ix**: `utilities/text/` (grep, sed, sort, tr, uniq, and awk, a
  language of its own), `time/` (date, cal), `process/` (ps, kill,
  time, free), `calc/` (bc, dc, hoc), `namespace/` (bind, mount,
  unmount).
- **The idea to keep**: what made the Unix pipe useful is these
  filters, not cat and wc. With grep, sort and uniq, rc on tiny-kernel
  can answer questions: `ls | grep tm | wc -l`.
- **How**: in `TinyUtilities.ml`, on its existing frame
  (`each_input`, `pieces`). sort, uniq and tr are 10 to 20 lines each.
  grep needs a regular expression matcher: Pike's backtracking one
  from "The Practice of Programming" handles `^ $ . *` in about 30
  lines, and character classes add about 10. It would serve sed too. sed is s, d,
  p, addresses and ranges, about 60 lines.
- **What to drop**: awk (a twin of awk is a language, and would be a
  plan of its own), bc and dc (hoc is enough, if a calculator is wanted
  at all: tiny-kernel has `calc`).
- **What needs the kernel**: date needs a clock that knows the date
  (tiny-machine has ticks, not a calendar); ps and kill need a call
  that lists processes (kill(pid) exists); namespace needs bind, which
  is a design decision for tiny-kernel, not a utility.
- **Test**: the same differential test as now, against mini-grep,
  mini-sort...; and lines through rc in `make check`.
- **Size**: about 200 lines for grep, sort, uniq, tr and sed.

### 3.2 Parser generators: tiny-yacc and tiny-lex

- **m-ix**: `generators/yacc/` (945 lines) and `generators/lex/` (648).
- **The idea to keep**: a grammar is turned into tables, and a small
  fixed driver runs them; a set of regular expressions is turned into
  one automaton. Both are the classic case of a program that writes a
  program.
- **How**: tiny-yacc as SLR(1), the simplest table construction that
  handles real grammars: the LR(0) items, the closure and goto, FOLLOW
  sets, the table, and the driver. tiny-lex as Thompson's construction
  then the subset construction, to a DFA.
- **What to drop**: LALR's lookahead propagation (SLR's conflicts are
  reported instead), precedence declarations beyond `%left` and
  `%right`, yacc's error recovery.
- **Test**: the grammars of m-ix's tests, or tiny-ml's expressions as
  a grammar: the same parse as m-ix's yacc, or the same conflicts.
- **Size**: 400 to 500 lines for both.
- **Note**: tiny-c and tiny-ml parse by hand, by recursive descent, and
  should stay so; tiny-yacc would be a tool of t-ix, not something its
  compilers depend on.

### 3.3 Typesetting: tiny-troff

- **m-ix**: `typesetting/troff/` (6,641 lines, with pic, a latex
  output, ixdoc) and `man/` (167).
- **The idea to keep**: text with requests (`.sp`, `.in`, `.ce`) and
  macros, read as a stream and set as filled and adjusted lines on a
  page. Text formatting was Unix's first application: roff, for Bell
  Labs' patent department, was the reason given for buying the PDP-11
  (1970), and troff, its successor, made Unix's manual pages.
- **How**: requests, number registers, strings, macros (`.de`), fill
  and adjust, then man's macros written in it. The output is text for
  a terminal (nroff's), and perhaps later a page drawn on tiny-kernel's
  screen.
- **What to drop**: pic, eqn, tbl, fonts and their metrics, the latex
  output, troff's escapes beyond the common ones.
- **Test**: `tiny/` has no manual pages yet; the test would be the
  output of the same text through m-ix's troff in nroff mode.
- **Size**: about 500 lines.

### 3.4 Applications: apps/

- **m-ix**: `apps/office/` (6,943 lines: a sheet, a document, draw,
  paint), `apps/music/` (2,652), `apps/page/` (293), `apps/misc/` (257).
- **The idea to keep**: for a spreadsheet, cells holding formulas,
  and a change propagated through the cells that depend on it. That is
  the idea of VisiCalc (1979), the first program people bought a
  computer for.
- **How**: `TinyAppSheet.ml` on `TinyLibGUI.ml`, as calc and temp are:
  a grid of cells, a formula language of `+ - * /`, cell references
  and `sum(a1:a5)`, recomputation in dependency order. A document
  editor and drawing come after, if wanted; TinyEditorScreen is already the
  text editor.
- **What to drop**: files in office formats, charts, styles.
- **Size**: about 300 lines for the sheet.

### 3.5 Sound: lib_audio/

- **m-ix**: `lib_audio/` (9,057 lines: formats, synthesis, instruments,
  effects, signal), which apps/music plays with.
- **The idea to keep**: sound as a stream of samples, and a synthesizer
  as functions from time to samples (oscillators, envelopes), mixed.
- **How**: first tiny-machine needs a sound device, designed as its
  screen was: a buffer of samples in memory that the machine plays,
  and on the host, a way to play them (SDL's audio, or a WAV file
  written for a test). Then tiny-kernel needs to give it to programs,
  and a `TinyLibSound.ml` and a small program that plays notes.
- **Cost**: the highest of this plan, since it starts with the
  machine, then the kernel, before the library. It is a plan of its own.

### 3.6 networking/

- **m-ix**: `networking/` (423 lines: Curl, Httpd, Timesync), host
  programs over Unix's sockets.
- **In t-ix already**: tiny-kernel's `get` and `httpd` (in C, in
  `TinyKernel/user/`) do what curl and httpd do, on tiny-kernel's own
  network stack. A host-side twin would only repeat them over Unix.
- **Decision**: no twin, unless one is wanted for the host. Timesync
  becomes interesting with date (3.1): tiny-kernel could ask the wire's
  other end for the time.

## 4. The order I suggest

1. **The text utilities** (3.1, without the kernel's part): the
   cheapest, on an existing frame, and they make tiny-kernel's rc a
   shell one can answer questions with.
2. **tiny-yacc and tiny-lex** (3.2): small, with a clear idea, and they
   complete t-ix's toolchain.
3. **tiny-troff** (3.3).
4. **A spreadsheet** (3.4).
5. **Sound** (3.5), as a plan of its own.

With all of them, t-ix would grow by about 2,000 lines, to about
26,000: still about a seventh of m-ix.

## 5. What was found

grep and sort (2026-10-16):

- **grep's regular expressions are a library, `tiny/TinyLibRegex.ml`**
  (the author: "could we move the regexp in a separate lib file?
  instead of inside TinyUtilities.ml ? (it could potentially be used
  by TinyEmacs?)"). It is Thompson's automaton with no captures, since
  grep asks only whether a line matches: about 120 lines with its
  parser. TinyEditorLine.ml keeps its own matcher, a backtracking one with
  captures, which sam's commands need (the author: "let's consider
  TinyEditor.ml separately"). For TinyEditorScreen, the library would need a
  search that says where the match is: Thompson's simulation can give
  the leftmost-longest match if each state in the set carries where
  its match started, about 15 lines more.
- **The pattern syntax is Plan 9's, strictly**: an alternative or a
  group with nothing in it, a class with no byte or a `-` with nothing
  on a side are errors, as in the twin. My first version accepted
  them (`x|` matched everything); the twin's rules are the simpler
  ones, with no special case for a `]` first in a class.
- **tiny-ml's `List.sort` was an insertion sort**, n * n comparisons:
  fine for a directory, not for sort on a file of thousands of lines.
  `TinyLibStd.ml` now has a merge sort, stable (contiguous halves, the
  first half's element first on a tie) and made of loops, so a long
  list does not fill tiny-ml's stack of values. Every program tiny-ml
  builds uses it; `TinyLibStd_test.sh` (stable pairs included) and
  tiny-kernel's check pass.
- **sort's key is a tuple**: the number or the text from the field, then
  the line itself, so `compare` orders by the key and then by the
  line's bytes. The twin leaves lines with equal keys in their input
  order under a global `-n`; tiny-utils orders them by their bytes, so
  its output does not depend on the input's order. The test's cases
  have no such ties; the difference is said in its header.
- **Checked**: 44 cases of grep and sort against mini-grep and
  mini-sort (160 cases in all); mini-mk's build on Linux prints the
  same as dune's; tiny-kernel's check has a line of grep and sort in
  pipes through rc. `utils` grew from 204 KB to 237 KB.
