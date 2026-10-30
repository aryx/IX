# languages/ml/debug

What mini-ml does for a debugger (docs/plans/plan_debugger.md).

Here:

- `Lines_ml`: the .ml's lines in the object, from the assembly's
  `// line n` marks, and the history.

Elsewhere, called from here or calling here:

- `Ir` and `Ssa`: a function's `line`, set by `Lower`
  (`Ssa_build` copies it); `Gen` and `Emit` write the `// line n`
  marks.
- `Gen`: a raise leaves the registers a trace's walk starts from
  (`raise_`, `ml_raise_pc`, `ml_raise_sp`, `ml_raise_lr`,
  `ml_raise_top`, and `ml_raise_c`).
- `runtime/frames.c`: the frames walked at an uncaught exception, by
  the program's tables; `runtime/exceptions.c` calls it.
- `CLI`: calls `Lines_ml.add` on each object.
- `debuggers/tests/acid_proc.sh`: mini-acid on programs of mini-ml's;
  `debuggers/tests/walk.sh`, a trace.
