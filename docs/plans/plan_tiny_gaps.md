# Plan: the tiny programs' gaps, what a person needs put back where cheap

A tiny-xxx keeps what is fundamental and drops the rest by what it
costs (the "What is dropped" of each header). The
test chosen for a program says what it needs, not what a person does
with it: tiny-shell's test is mini-mk's recipes, which never meet a
terminal, so its interactive prompt was dropped, and at a terminal
tiny-shell looked broken (no prompt, nothing run until ^D). Put back
(9f00759, about 25 lines): "part of the essence of a shell, to be
interactive". This plan asks the same question of every tiny program:
what does a person do with it, and does it still let them?

## Essential and cheap

1. **tiny-editor reads all its input before running any of it**
   (TinyEditor.ml, `input := In_channel.input_all stdin`), as
   tiny-shell did: at a terminal, typed commands do nothing until ^D.
   An editor is more interactive than a shell (print, look, change).
   - How: read another line when the parser reaches the end of what it
     has: in `peekc`, and where `a`/`i`/`c` read their text lines
     (`String.index_from_opt !input !ip '\n'`). About 8 lines.
   - Check: through a pseudo-terminal (`script -qec`), as tiny-shell's
     was; test.sh against sam -d unchanged.
   - Done: `refill` reads a line when the parser is at the end (the
     text lines' loop calls it too), 9 lines; each command's output
     timed through `script -qfec` as its line is typed; test.sh
     against sam -d, all passed.

2. **tiny-editor has no undo** (sam's `u`, dropped). At a terminal it
   is what makes a mistake cheap. The header's exercise already says
   how: a command's changes are a list against the old text, so their
   inverses (the text each replaced) are a list too, applied the same
   way; `u n` undoes n commands. About 15-20 lines.
   - Check: test.sh scripts with u, against sam -d.
   - Done: `commit` returns a command's inverse, `u n` commits records
     from one list and pushes their inverses on the other (so `u-n`,
     sam's redo, came for nothing); `e` is undoable, as in sam. Dot
     after u is the one before the command (sam's: the one when its
     first change was made, the first match of an x); a w makes every
     other state modified (sam's menu says unmodified after an undo
     past a w, though its quit then warns). Six test.sh cases against
     sam -d, all passed.

3. **tiny-pi has no input**: the UART's receive side is dropped (FR
   says "receive empty" forever), so no program on it can read a key.
   tiny-machine has console input (-8(r0)); tiny-pi, none. It is the
   header's exercise "the UART's receive interrupt and a shell".
   - How: polling first: FR's RXFE bit from the host's stdin, DR read
     a character (about 10 lines); then the receive interrupt, its
     line through the controller (about 10 more).
   - Check: a TinyMachinePi_tests/ program that echoes what it reads,
     here, under mini-qemu and under QEMU (raspi1ap), as the others.
   - Done, both steps: DR read, FR's RXFE, IMSC, and line 57 in the
     controller's bank 2 (mini-qemu's Pl011.ml and Intc.ml), about 40
     lines. As tiny-machine's console, nothing read before a program
     asks; unlike it, a pipe is polled, not read whole: every program
     that writes reads FR, and a test's pipe left open blocked it. A
     terminal in raw mode, as mini-qemu's (Enter a \r, ^C quits and
     restores it). echo.s (by the interrupt, upper case, ^D ends)
     with echo.input: the same here, under mini-qemu and under QEMU
     (a chardev file with input-path); TinyMachinePi_test.sh, 0
     failures.

4. **tiny-c's errors have no line**:

       $ printf 'int main(void) {\n  int x;\n  x = 1 +;\n  return x;\n}\n' > bad.c
       $ tiny-c -o bad.s bad.c
       bad.c: expected an expression

   For a compiler a person uses, where is half of the error. tiny-ml
   says `line 3:`, tiny-assembler the function's file and line.
   - How: a (file, line) per token beside the tokens (the lexer's
     line from its position; a macro's tokens get their use's), the
     error printed with the last token's; an #include'd file's errors
     then placed right too. About 15 lines.
   - Check: TinyC_tests/ unchanged; an error test or two.
   - Done: the lexer gives each token its (file, line), the line
     counted as the tokens come (in the order of their positions); a
     macro's tokens take their use's; an error is printed with the last
     token read's (`semi.c: line 3: expected ;`: the line where the ;
     is missing, not the next). TinyC_test.sh: its programs unchanged,
     and four errors (an expression, a ;, in an #include'd file, in a
     macro's use), 0 failures.

## Smaller

- **tiny-db**: reads and runs a line at a time already, and goes on
  after an error; only no prompt at a terminal (sqlite's `sqlite>`).
  3 lines, `Unix.isatty stdin`.
  - Done, with a help statement: a table made and queried first (the
    header's examples), then the stages and the other statements, then
    the database's tables with their columns and indexes (tiny-db had
    no way to list them); at a terminal a banner naming help, and a
    `tiny-db> ` prompt. Each example of the help run as shown.
- **tiny-shell**, left from 9f00759:
  - a line ending in `|` or `&&` is not continued: `pipe` and
    `and_or` skip the newline, then take an empty command at the end;
    they should say "incomplete" there, as an open brace does. A couple
    of lines.
  - `$status` after a signal is OCaml's number (`signal -6` for an
    interrupt): `describe` prints `Sys.sigint` as is; the system's
    numbers (2), or rc's names. A bug, not only interactive.
  - `if not` (rc's else): borderline, `||` covers most of it.

## Considered, not cheap (each a decision of its own)

- **tiny-ml's records and arrays**: arguably essential to an ML, but
  the labels' typing is more like 60-100 lines.
- **tiny-kernel**: the files lost at the halt (a disk, -d: not cheap);
  no kill, so ^C cannot stop a runaway program (moderate).
- **tiny-c**: floats, macros with arguments, #if: none cheap.
- **tiny-vcs, tiny-build, tiny-assembler, tiny-mkfs, tiny-cpu,
  tiny-arm, tiny-machine**: nothing essential missing for their use.

## Order

1-4, then tiny-db's prompt, then tiny-shell's two. Each program's
header updated as it goes: what it drops, what it keeps, and the
exercises that became features taken off the exercises' list.

## Next: tiny-ml's records and arrays, then tiny-kernel with them

Chosen after the list above (2026-09-28): tiny-ml without records and
arrays shapes every program it compiles, tiny-kernel first (its
process table and files are tuples taken apart by position, and
lists). The cost came down from 60-100 lines by reusing what is there:

- **A label is a constructor's kind of scheme.** A type declaration
  registers each constructor with a scheme (`TCon ("%c", res :: args)`,
  instantiated by `con_type`); a record's labels are registered the
  same way, the record's type to the field's, with the field's index.
  `e.l` is then one instantiation and one unify, as a constructor's
  application; a record is a block, as a tuple, a field an index.
- **Type-directed disambiguation, cheaply.** Labels as schemes make
  the last declared win when two records share one: OCaml's before
  4.01, annoying. Instead `e` is inferred first, and when its type is
  already a record's, `l` is looked up in that record: three lines.
  What makes it known is an annotation, `let f (p : proc) = p.pid`:
  optional (forcing them on every toplevel function would not shrink
  the checker: let-polymorphism is still needed, for the prelude's
  List functions too), and an ambiguous label on an unknown type says
  "annotate". Annotations: about 5 lines, of_texpr already parses
  types for declarations.
- **Cut**: no record patterns (`{ a; b } ->`), no `{ r with ... }`;
  `e.l`, `{ l = e; ... }` and `e.l <- v` (mutable fields) are what the
  kernel needs.
- **Arrays as strings are**: `'a array` built in, Array.make, length,
  get and set externals of the C runtime (the bounds check there, a
  fatal error as ocaml-light's), `a.(i)` and `a.(i) <- v` sugar in the
  parser: about 10 lines of OCaml.
- **The estimate**: about 40 lines for records, 10 for arrays.
- **The check**: TinyML_test.sh, programs with records and arrays
  printing what ocaml-light's ocamlopt makes them print (the test's
  contract), both back ends (arm64, -tm).
- **Records done**: 70 lines of code (1277 to 1347 in TinyML.ml), not
  40: a record's construction needs its own typing (the record whose
  labels are exactly these, the fields in its order). The labels in
  record_labels, a Hashtbl.add each (several records may share one);
  label_for filters them by the type e already has. Annotations are
  PAnnot patterns (a parameter's becomes a let, as any pattern's).
  languages/ml/tests/tiny/records.ml, recorded from ocaml-light's
  ocamlopt (fields right to left, as it evaluates them): ok on arm64,
  with a 64-word heap, and on -tm; the shared label (by annotation) and
  the five errors checked by hand, ocaml-light having no
  disambiguation; tiny-kernel's make check, rebuilt, ok.
- **Arrays done**: 16 lines of code in TinyML.ml (10 estimated), 51 of
  C in TinyML_core.c (not counted by loc.py). A block of tag 0, as a
  tuple; the empty one static, as OCaml's atom: Cheney's copy writes
  its forwarding address in a block's first field, which a block of
  no field does not have (the next block's header). a.(i) <- v is
  evaluated i, a, then v, ocaml-light's order (found by the test):
  the sugar lets i and a first. arrays.ml and array_bounds.ml
  recorded from ocaml-light's ocamlopt, with the orders of a.(i) and
  r.l <- v; TinyML_test.sh, 0 failures; tiny-kernel's check, ok.
- **Then tiny-kernel**: its process table and descriptors as records,
  p.state <- ... instead of tuples by position: shorter, clearer, and
  the design's real test (make check in TinyKernel/).
