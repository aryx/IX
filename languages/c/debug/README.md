# languages/c/debug

What mini-cc does for a debugger (docs/plans/plan_debugger.md).

Here:

- `Acid`: `-a`'s declarations of the program's types in acid's
  language, 5c's text byte for byte (`languages/c/tests/acid.sh`);
  with `-g` the same in the object, which mini-ld puts in the program.

Elsewhere, called from here or calling here:

- `Declare`: calls `Acid.acidtype` once a structure is aligned and
  `Acid.acidvar` once a name is declared; `fnline` and `nameline`, a
  function's line.
- `Lexer`: a name's line, for `Declare.nameline`.
- `Pre`: the files read as 5c's history (`history`, `push_file`), and
  `depth`, for `-aa`; the positions are also its errors'.
- `Emit`: each instruction's line (its function's), the history and
  the declarations in the object.
- `CLI`: `-a`, `-aa`, `-n`, `-g`.
- `debuggers/tests/acid_proc.sh`: mini-acid on a program of mini-cc's.
