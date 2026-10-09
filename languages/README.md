# languages/: ix's compilers, one directory per language

Each compiler writes mini-asm's objects (`assembler/Asm.ml`), which
mini-ld (`linker/`) encodes and links: Plan 9's split, where the
compiler never knows an address. The assembler and the linker stay
outside: they are the machine's end of the toolchain, shared by every
language, not a language of their own.

| folder | language | program | plan |
|---|---|---|---|
| `c/` | Plan 9's C, as 5c and 7c at `-O0`, byte for byte | mini-cc | [plan_cc.md](../docs/plans/done/plan_cc.md) |
| `ml/` | ocaml-light's ML, native; its target: mini-9pi | mini-ml | [plan_ml.md](../docs/plans/plan_ml.md) |

And the languages that are run, not compiled to the machine: each is
read, and run by a machine of its own, in OCaml.

| folder | language | program | plan |
|---|---|---|---|
| `smalltalk/` | Smalltalk-80 from the Blue Book, with Squeak's Morphic; mini-squeak's language | mini-smalltalk | [plan_system_squeak.md](../docs/plans/plan_system_squeak.md) |
| `scheme/` | a small Scheme and How to Design Programs' Beginning Student, on a CESK machine; its reader of s-expressions with it; mini-drscheme's language (`editors/drscheme/`) | mini-scheme | [plan_scheme.md](../docs/plans/done/plan_scheme.md) |
| `pascal/` | Pascal as Pascal-P and UCSD Pascal ran it: one pass to P-code, and a P-machine (the machine talks: `lib_terminal/`) | mini-pascal | [plan_pascal.md](../docs/plans/plan_pascal.md) |
| `formula/` | a spreadsheet's formulas (`=A1+SUM(B1:B3)`), read and evaluated: the 7GUIs' Cells (`examples/`) | a library | [plan_gui.md](../docs/plans/plan_gui.md) |

The one-file variants are in `tiny/` (TinyC.ml, TinyML.ml), beside
the others.
