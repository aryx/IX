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

## Smaller

- **tiny-db**: reads and runs a line at a time already, and goes on
  after an error; only no prompt at a terminal (sqlite's `sqlite>`).
  3 lines, `Unix.isatty stdin`.
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
