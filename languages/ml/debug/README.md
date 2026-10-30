# languages/ml/debug

What mini-ml does for a debugger (docs/plans/plan_debugger.md).

Here:

- `Lines_ml`: the .ml's lines in the object, from the assembly's
  `// line n` marks, and the history.
- `Acid_ml`: `-g`'s descriptions of the unit's values and their
  types (constructors by tag, records' fields), acid's text in the
  object, which mini-ld puts in the program's `.acid`; port.acid's
  `ml()` prints a value by them.

Elsewhere, called from here or calling here:

- `Ir` and `Ssa`: a function's `line`, set by `Lower`
  (`Ssa_build` copies it); `Gen` and `Emit` write the `// line n`
  marks.
- `Gen`: a raise leaves the registers a trace's walk starts from
  (`raise_`, `ml_raise_pc`, `ml_raise_sp`, `ml_raise_lr`,
  `ml_raise_top`, and `ml_raise_c`).
- `runtime/frames.c`: the frames walked at an uncaught exception, by
  the program's tables; `runtime/exceptions.c` calls it.
- `CLI`: calls `Lines_ml.add` on each object, `Acid_ml.decls` with
  `-g`.
- `Typing.global_types` (the values' types, inferred) and
  `Resolve.type_conses`, `Resolve.type_fields` (a type's
  constructors and fields), what `Acid_ml` reads.
- `debuggers/tests/acid_proc.sh`: mini-acid on programs of mini-ml's;
  `debuggers/tests/walk.sh`, a trace.
