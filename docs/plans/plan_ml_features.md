# Plan: what mini-ml could gain next to shorten ix: `[%bytes]`, mini-yacc's parameterized rules, the runtime in ML (`languages/ml/`, `generators/yacc/`, `lib_core/`)

Companion of [`plan_ml_bootstrap.md`](plan_ml_bootstrap.md), whose
constructs are in use (`[%bits]`, `[@@deriving show]`, `type t =
[%mli]`, `[%list]`, `|!`) and whose two goals are reached. The author
(2026-10-05): "what could be a cool new features to add to mini-ml to
help reduce the code of ix in total?". On the answer, four candidates:
"let's save this as a plan document, but let's not put 2. Those
signatures are useful in the .ml too. The rest I like."

Done: 2, for the database's grammar (its Status). The rest is a census,
two candidates, and what the numbers say is not worth a construct.

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
| a definition of one of those | 56 | 19 | a `Binary` module (1) |
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
| 1. `Binary`, then `[%bytes "..."]` | 60 to 120 (first said 150 to 250: see below) | 48 (`Binary`, measured), ~130 in mlpp |
| 2. `list(x)`, `option(x)`, `separated_list(s, x)` in mini-yacc | 60 to 100 | 60 to 80 in mini-yacc |
| 3. more of the runtime in ML | 500 to 1,000 of C | 300 to 500 of ML, and the compiler's part |

### 1. `[%bytes "..."]`: `[%bits]` for a string's bytes

The author (2026-10-05): "I like a lot this %bytes! great idea. so
nice it follows %bits".

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

- **First, `Binary`** (first named `Wire`; the author: "Is Wire a
  good module name for this?", then "let's rename it to Binary": a
  disk's sector and an executable's header are on no wire, and Go's
  `encoding/binary` is the same thing) (`lib_core/commons`; the author, 2026-10-05: "maybe
  we could start the Wire module", "we actually recently added more
  P9_wire code that probably could reuse some Wire functions"). **Done
  for five files**: a number read at a string's offset (`Binary.le16`,
  `le32`, `be16`, `be32`, `u8`), added to a buffer (`add_le32`...), set
  in bytes (`set_le16`...); 32 bits by halves, one statement of what
  arm's 31-bit int does to them, where each file had its own (FAT's
  `land 0x3fff`, 9P's `asr 16`, git's `land 0xffffffff`). Converted:
  `lib_9p/P9_wire` (its writers; its cursor stays its own),
  mini-dossrv's `Fat`, mini-fdisk, mini-mkcard, mini-git's `Pack`.
  **The lines: 17 out of the five files, 48 in `Binary` (20 of code, 28
  its interface): +31.** Of the census's 56 definitions about half are
  out of its reach: the kernels' (ocaml-light's dialect and
  `kernel/lib`'s own `Machine.le32`), `tiny/`'s (one file each),
  `lib_core/system/Unix` (below `commons`). Left, within reach:
  `lib_graphics/Display`, `machine/Plan9`, `machine/Elf`,
  `raspberry/Usernet`, about 15 lines. So `Binary` doesn't pay in lines;
  what it gives is the 31-bit rule said once.
- **The linker's** (the author, 2026-10-05: "lots of place dealing
  with little/big endian in the linker and 8, 16, 32, 64 int output,
  that maybe we could factorize in this Wire module? independently of
  the work on %bytes"). `Exe` had the idea already, for one order: a
  header as a list of fields, `fields [ W 2; L 1; Q off; S name ]`.
  Now `Binary`'s, for the two: `Binary.le` and `Binary.be` of a `field list`
  (`B`, `W`, `L`, `Q`, `S`: 1, 2, 4, 8 bytes, and bytes as they are),
  so Plan 9's a.out header, big-endian, is one list too; and
  `Binary.set_le b o width n`, a number's `width` low bytes, for
  `Link`'s data (an immediate, an address, a float's bits: three loops
  of shifts). The recorded bytes are the same (`golden.sh`: 64
  executables, ELF, Plan 9's, Mach-O, raw). `Exe` 11 lines shorter,
  `Binary` 30 longer (78 in all, 39 its interface). The rest of the
  linker's bytes are the instructions' words, `Bytes.set_int32_le`, one
  line an architecture: left. A list of fields is `[%bytes]` as an
  expression, without mlpp: what is left for the construct is reading
  (the `let` pattern).
- **mlpp's reach** (the author): "we can't use it in mini-ml and some
  of lib_core since we depend on mini-ml -pp": `[%bytes]`, as the
  other constructs, is not for `languages/ml/` nor for what mini-ml
  links of `lib_core/`; there, `Binary`.
- **Then the construct**, for what still reads badly: offsets counted
  by hand (`o + 13`), a structure's fields in a row. The payload is
  `[%bits]`'s, a width in bytes: `le` or `be` first, `name:n`, `_:n`
  for bytes that don't matter, a constant for bytes that must be
  those; and `name:s`, 9P's string, its length in two bytes before it
  (to settle: whether a protocol's own type belongs in the payload, or
  a `name:*` taking what is left).
- **As an expression**: a string, the fields packed in order, by
  `Binary`'s functions. **As a pattern**: on a string and an offset (to
  settle: how the offset is written; `[%bits]` matches an integer, a
  value by itself), the fields bound, the constants tested.
- A field of 8 bytes is an `int` (9P's offsets, as `le64` today) or an
  `int64` (the emulators'): the payload says which (`off:8` and
  `off:8L`).
- `pp/Bits`'s lexer, reused. About 80 lines in mlpp.
- **Read again against the code** (2026-10-05): what ix reads is
  mostly one layout's fields at scattered offsets (FAT's boot sector:
  11, 13, 14, 16, 17, 19, 22, 32; `statx`: 16 to 136), not a match's
  clauses; and a message written field by field is already a line
  (`lib_9p/P9_wire`). So, proposed: a `let` pattern too (`let [%bytes
  "le @11 sector:2 per_cluster:1 reserved:2"] = boot in`); `@n`, a
  position, for no skipped bytes counted; no total (a layout is a
  string's start); the subject `s`, or `(s, o)` written as a pair;
  `x:4` an int, `x:4l` an int32, `x:8L` an int64, `x:s2` signed,
  `x:c6` six bytes as a string, `x:*` the rest; `le` and `be` tokens,
  switchable; a constant `0xaa55:2`, in a match's clause only. About
  130 lines in mlpp, and 60 to 120 saved, not 150 to 250: worth more,
  as `[%bits]`, for what it reads like.
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

**Status (2026-10-06): done for the database's grammar, by menhir's
syntax.** The author, on dune's side: "follow the syntax of menhir, so
the grammar file can be processed either by menhir or by mini-yacc";
"ideally those list(x) option(x) are really just sugar"; "menhir is a
very different engine (LR(1), with lots of code); we do not want to do
the same for mini-yacc". And of the two grammars: "let's do 2 [SQL
only] for now and see".

- **mini-yacc** (+36 lines of code, 33 of them in `Yacc`'s reader; 715 lines
  with its interfaces, from 661): a symbol may be `f(x)` or `f(sep, x)`
  for menhir's `option`, `boption`, `loption`, `list`, `nonempty_list`,
  `separated_list`, `separated_nonempty_list`. Each use is a
  non-terminal with rules of its own, added after the grammar's, named
  as menhir names it (`separated_nonempty_list_COMMA_column_name_`).
  `Lalr`, `Output`'s tables and `Parsing` don't know: LALR(1) as
  before. The rest of menhir's (rules with parameters of one's own,
  `x = symbol`, `x?`, `$startpos`) is refused, with its line.
- **dune**: `(menhir (modules Parser))` in `database/dune`, `(using
  menhir 2.1)`; menhir's parser is code, with no library to link. One
  more opam package to build ix by OCaml (the Dockerfile's list); the
  mkfile's build is as it was.
- **A syntax error** is `Parser.Error` by menhir and
  `Parsing.Parse_error` by mini-yacc: `Sql` catches both, and mini-yacc
  declares `exception Error` in every parser so that the name is there.
  To do if ML's grammar follows: one exception (mini-yacc's parser
  raising its `Error`), and the callers'.
- **`database/Parser.mly`**: 345 lines from 385. 9 rules gone
  (`sql_queries`, `opt_unique`, `opt_distinct`, `opt_constraints`,
  `opt_where_condition`, `opt_join_condition`, `opt_outer`, and two
  lists become a line each; `expression_list` is `aliased`, an
  element). **One list stays by hand**, `column_dec_list`: menhir's
  lists are recursive on the right, and after a column's declaration a
  comma is then a column's or a key's, which one token doesn't say
  (the rule recursive on the left has no such choice). So in lines,
  this first grammar pays for mini-yacc's part and no more: -40 for
  +36.
- **Checked** (`generators/tests/trees.sh`): the automaton, still state
  by state: `menhir --only-preprocess-for-ocamlyacc` writes the grammar
  with the uses made rules, ocamlyacc builds its automaton, and
  mini-yacc's 251 states pair with it, no difference (so mini-yacc
  expands as menhir does); no conflict (the two said before were C's,
  not SQL's), so menhir's LR(1) parser and the LALR(1) one are the same
  language. The trees: 165 inputs by menhir's parser and by
  mini-yacc's, the same bytes, the 8 errors at the same place. chidb's
  differential tests; `make test-lite` (mini-chidb built by ix's
  tools).
- **ML's grammar, not done**: under menhir the `Parsing` module is not
  kept (`Parsing.symbol_start_pos ()` gives -1), and ML's grammar takes
  its positions there, in its header's `loc ()`, `whole ()`, `span_of`
  behind `mkexp`, `mkpat`...: about 150 lines would pass menhir's
  `$sloc` from each action (`mkexp $sloc (...)`, as OCaml's own
  grammar), and mini-yacc translate `$sloc` and `$loc($n)` (about 10
  lines). Its list rules also need a look each, as `column_dec_list`
  did.

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
  `I64.( )` took. (Done all the same, 2026-10-05, as a showcase of mlpp
  and for `Prelude`: `plan_ml_bootstrap.md`, "Type classes", which has
  the survey of where ix would use them: the linker's `'m machine`,
  and little else.)
- **Options**: 893 clauses on `Some` and `None`, 330 `-> ()`. Nothing
  found that OCaml's parser reads and that does more than `|!`,
  `let*` and `Option.iter` do.

And by the author:

- **A `val`'s type put by mlpp on its definition**, so that the `.ml`
  could drop its parameters' annotations (1,683 `val`s): "Those
  signatures are useful in the .ml too".

## Phasing

1. `Binary`; the 56 definitions out; the lines counted.
2. `[%bytes]` on `P9_wire.ml`; counted; then the other files, or not.
3. Marshal in ML; its lines and its time; then a plan for the rest of
   the runtime, or not.
4. mini-yacc's parameterized rules, if dune running mini-yacc is
   wanted.
