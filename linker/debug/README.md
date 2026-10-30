# linker/debug

What mini-ld does for a debugger (docs/plans/plan_debugger.md): the
tables and data `-g` adds to a program, which mini-acid, mini-nm and
a trace read.

Here:

- `Symtab`: Plan 9's symbol table and pc/line table, 5l's bytes
  (`linker/tests/symtab.sh` compares them with goken's).
- `Debug_link`: what an object gives them, kept as it is read: its
  history as File symbols, each function's parameters and locals
  (autos), and the acid declarations, written as the data `.acid`.

Elsewhere, called from here or calling here:

- `Program`: the `File` kind of a symbol, the `auto` type, a prog's
  `autos`, the program's `nfiles` and `acid`.
- `Link.add_object`: calls `Debug_link.history` and `Debug_link.autos`;
  an object with no history has its lines put at 0.
- `CLI`: `-g` (the tables, and `Debug_link.acid_data` before the
  data's layout).
- `Exe`: the a.out's header sizes of the two tables, and the tables
  after the data.
- The assembler's `Asm`: an object's history and acid declarations,
  after its items (the object's format, which mini-asm, mini-cc and
  mini-ml write).
