# Plan: what mini-ml could gain next to shorten ix: `[%bytes]`, mini-yacc's parameterized rules, the runtime in ML (`languages/ml/`, `generators/yacc/`, `lib_core/`)

Companion of [`plan_ml_bootstrap.md`](plan_ml_bootstrap.md), whose
constructs are in use (`[%bits]`, `[@@deriving show]`, `type t =
[%mli]`, `[%list]`, `|!`) and whose two goals are reached. The author
(2026-10-05): "what could be a cool new features to add to mini-ml to
help reduce the code of ix in total?". On the answer, four candidates:
"let's save this as a plan document, but let's not put 2. Those
signatures are useful in the .ml too. The rest I like."

Nothing here is done: a census, three candidates, and what the numbers
say is not worth a construct.

## Principles

Those of `plan_ml_bootstrap.md`: a construct OCaml doesn't have is
mlpp's, in a syntax OCaml's parser reads; it pays for itself in lines,
or stays small, or goes; each change in the ledger there. And one of
this plan's:

- **A library before a construct.** Where a module of `lib_core/commons`
  takes the lines, no line of mini-ml is spent; the construct is for
  what is left after it.

## The census

`languages/ml/tests/ix_features.py --next` (2026-10-05): regexps, a
line counted when it matches, over the 314 `.ml` files outside the
tests and the stdlib (55,595 lines). Close, not exact.

| idiom | lines | files | candidate |
|---|---:|---:|---|
| a call of `get16`, `put32`, `le32`, `u16`... | 325 | 38 | `[%bytes]` (1) |
| a definition of one of those | 56 | 19 | a `Wire` module (1) |
| `Bytes.get_int32_le`, `Buffer.add_uint16_be`... | 113 | 29 | `[%bytes]` (1) |
| `Char.code s.[o]` | 130 | 65 | `[%bytes]`, for some |
| a rule named as a list or an option, in the ML and SQL grammars | 39 of 127 rules | 2 | mini-yacc (2) |
| C and assembly under mini-ml: the runtime, `lib_core/libc` | 2,978 and 7,741 | | the runtime in ML (3) |
| a rebuilding clause, `C (a, b) -> C (f a, f b)` | 11 | 3 | none (`[@@deriving map]`) |
| `C -> "name"` | 25 | 16 | none (`[@@deriving enum]`) |
| `Obj.magic` | 9 | 7 | none |
| `let x = ref` | 609 | 164 | none: no line saved |
| a clause `\| Some x ->` or `\| None ->` | 893 | 146 | none found |
| a clause `-> ()` | 330 | 121 | none found |
| `Int32.`, `Int64.` | 605 | 69 | `I64.( )`, which exists; and (3) |

The grammars' count was first said to be 63 of 127: a regexp that took
any rule's name with an `s` in it. By the rules' names (`list`, `opt`,
`seq`, a plural), 39.

## The candidates

Every "saves" is a guess, to be measured on a first file before the
rest is converted, as `[%bits]` was on `machine/Arm32.ml`.

| candidate | saves | costs |
|---|---:|---:|
| 1. `Wire`, then `[%bytes "..."]` | 150 to 250 | ~40 (`Wire`), ~80 in mlpp |
| 2. `list(x)`, `option(x)`, `separated_list(s, x)` in mini-yacc | 60 to 100 | 60 to 80 in mini-yacc |
| 3. more of the runtime in ML | 500 to 1,000 of C | 300 to 500 of ML, and the compiler's part |

### 1. `[%bytes "..."]`: `[%bits]` for a string's bytes

ix packs and reads bytes in 38 files, each with its own helpers:
`kernel/9pi/files/P9_wire.ml` (9P's messages), `network/ip/` (IP's and
TCP's headers), `lib_core/system/Unix.ml` (`statx`, a `sockaddr`, a
`termios`), `linker/Exe.ml`, `kernel/tools/` (mini-mkcard's MBR and
FAT), mini-git's index and packs, mini-chidb's pages.

```ocaml
(* P9_wire.ml today *)
| Request.Read (fid, off, count) -> 116, le32 fid ^ le64 off ^ le32 count
| 113 -> Response.Open (getqid s o, get32 s (o + 13))
(* with it *)
| Request.Read (fid, off, count) -> 116, [%bytes "le fid:4 off:8 count:4"]
```

- **First, `Wire`** (`lib_core/commons`): `get16`, `put32`... once, for
  the two byte orders, in the place of the 56 definitions. No line of
  mini-ml. To settle: what a `put` gives (a string, as `P9_wire`'s
  `le32 v ^ ...`, or bytes written at an offset, as `Unix.ml`'s
  structures), probably both.
- **Then the construct**, for what still reads badly: offsets counted
  by hand (`o + 13`), a structure's fields in a row. The payload is
  `[%bits]`'s, a width in bytes: `le` or `be` first, `name:n`, `_:n`
  for bytes that don't matter, a constant for bytes that must be
  those; and `name:s`, 9P's string, its length in two bytes before it
  (to settle: whether a protocol's own type belongs in the payload, or
  a `name:*` taking what is left).
- **As an expression**: a string, the fields packed in order, by
  `Wire`'s functions. **As a pattern**: on a string and an offset (to
  settle: how the offset is written; `[%bits]` matches an integer, a
  value by itself), the fields bound, the constants tested.
- A field of 8 bytes is an `int` (9P's offsets, as `le64` today) or an
  `int64` (the emulators'): the payload says which (`off:8` and
  `off:8L`).
- `pp/Bits`'s lexer, reused. About 80 lines in mlpp.
- Converted first: `P9_wire.ml`, whose messages 9P's manual draws as
  the payload writes them, and whose tests are mini-9pi's sessions.

### 2. Parameterized rules in mini-yacc

Menhir's `list(x)`, `nonempty_list(x)`, `option(x)`,
`separated_list(sep, x)`, `separated_nonempty_list(sep, x)`: each use
expanded to a rule of its own before the automaton is built, so the
LALR(1) construction doesn't change.

- In `languages/ml/Parser.mly` and `database/Parser.mly`: 39 rules of
  127, three or four lines each. Not `languages/c/Parser.mly`, 5c's
  grammar rule for rule.
- A list's value is in the source's order (`$1 @ [ $2 ]` and
  `List.rev` are what the rules do by hand today).
- **The cost outside mini-yacc**: dune builds the grammars with
  ocamlyacc (`(ocamlyacc Parser)`), which doesn't read them. So dune
  runs the workspace's mini-yacc, as it runs `%{bin:mini-ml} -pp`; and
  mini-yacc is then in OCaml's build of ix, not only in ix's own. To
  decide before anything: is that wanted (the author, of mini-lex and
  mini-yacc: "compatible with ocamllex and ocamlyacc so we can use them
  only when using also mini-ml").
- The automata are no longer ocamlyacc's to compare with
  (`plan_lex_yacc.md`'s check, state by state): the check becomes the
  trees, on the two corpora.
- 60 to 80 lines in `generators/yacc/`.

### 3. More of the runtime in ML

The largest pool: `runtime.c` is 2,734 lines, the libc under it 7,741.
Twice already a piece of C became ML and shrank: `Unix`, each function
a system call by one primitive (`plan_ml_bootstrap.md`, step 8), and
`Lexing` and `Parsing`, 292 lines for ocaml-light's 796 with no C
engine. The candidates, `runtime.c`'s sections:

| section | lines of C | in ML, what it needs |
|---|---:|---|
| Marshal | 478 | `Obj` (a block's tag, size, fields; a block made), a table of the blocks met |
| channels | ~300 | `read` and `write` (Linux's by number, Plan 9's by the libc), a buffer |
| MD5 | 140 | arithmetic on 32 bits, unboxed: an `int` has 31 on arm |
| the floats' printing and reading (`libc/ix/fmt.c`) | 603 | arithmetic on 64 bits, unboxed |

- **The compiler's part**: an `int64` or `int32` in a register between
  operations, boxed only when stored ("Later: optimizations" of
  `plan_ml_bootstrap.md`, there for `machine/Arm64.ml`'s speed). So it
  pays twice; and it is an optimization, so switchable, the simple
  path kept (`languages/ml/opti/`).
- **Marshal first**: it needs nothing new of the compiler. Its test is
  there (`tests/modern/marshalled.ml`, the bytes OCaml 4.14's), and
  ix's objects and libraries are marshalled values: the fixed point
  (`mkfiles/fixpoint.sh`) says whether they are still the same.
- With each section gone, the libc's files only it called go too: to
  count then.
- **The risks**: speed (a channel's `input_char` is in every lexer's
  loop; Marshal reads every object linked), to measure before and
  after; and what the kernels link of the runtime (mini-9pi's is this
  one, with `-Dplan9` for a Plan 9 program).
- Large enough for a plan of its own, once Marshal has said what a
  section in ML costs and saves.

## Not worth a construct

By the census:

- **`[@@deriving map]`**: 11 rebuilding clauses.
- **`[@@deriving enum]`** (a constructor's rank and name): 9
  `Obj.magic`, 25 clauses.
- **A local that is assigned** for `let x = ref`: 609, but a line
  stays a line.
- **Type classes**: their main use in ix was Int64's arithmetic, which
  `I64.( )` took.
- **Options**: 893 clauses on `Some` and `None`, 330 `-> ()`. Nothing
  found that OCaml's parser reads and that does more than `|!`,
  `let*` and `Option.iter` do.

And by the author:

- **A `val`'s type put by mlpp on its definition**, so that the `.ml`
  could drop its parameters' annotations (1,683 `val`s): "Those
  signatures are useful in the .ml too".

## Phasing

1. `Wire`; the 56 definitions out; the lines counted.
2. `[%bytes]` on `P9_wire.ml`; counted; then the other files, or not.
3. Marshal in ML; its lines and its time; then a plan for the rest of
   the runtime, or not.
4. mini-yacc's parameterized rules, if dune running mini-yacc is
   wanted.
