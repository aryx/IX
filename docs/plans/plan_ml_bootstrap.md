# Plan: mini-ml compiles ix, and mlpp, the ML beyond OCaml: bit fields, deriving, `type t = _` (`languages/ml/`, `languages/ml/pp/`)

Companion of [`plan_ml.md`](plan_ml.md), whose "Out of scope" put
self-hosting aside as "a project of its own": this is that project,
grown to all of ix's OCaml. The questions that opened it (the author,
2026-09-30): "how hard would it be to extend the mini-ml to accept new
constructs, like let* or a match xxx | exception Xxx -> ...", then
type classes, then "more generally, can you analyze the all code of
ix/, and imagine new ml features that would help reduce code? Also how
much we need to extend mini-ml to be able to parse all the code in ix/
and so be able to bootstrap mini-ml". On the answer: "I am also very
ok in rewriting the OCaml code to use less advanced features, so we
would need less porting in mini-ml", and "I like the cheap features to
add that are mostly sugar, I like poor's man deriving, I like a lot the
Bitfields patterns". And on the plan's first draft, which put those in
mini-ml: "did you mention also the idea of mlpp ? to put advanced
features not even in OCaml?", "the bits pattern are such a thing for
instance"; and on mlpp as a separate tool: "mini-ml -pp is also very
fine!".

## Context

mini-ml compiles ocaml-light's dialect: mini-9pi's kernel is written
in it and parses (135 of `kernel/`'s 136 files). The rest of ix, the
toolchain, the emulators, the tools and mini-ml itself, is written in
today's OCaml, and 260 of ix's 497 `.ml`/`.mli` files don't parse
(`languages/ml/tests/parse_ix.sh`, 2026-09-30):

| directory | files | fail |
|---|---:|---:|
| kernel | 136 | 1 |
| languages | 97 | 38 |
| version_control | 56 | 45 |
| raspberry | 37 | 33 |
| database | 29 | 23 |
| machine | 27 | 22 |
| builder, shell, editor | 63 | 51 |
| assembler, linker | 22 | 20 |
| tiny | 16 | 15 |
| lib_core, lib_compression, lib_security | 13 | 12 |

Two goals, in this order:

1. **The bootstrap**: mini-ml compiles its own sources, and the result,
   compiling them again, gives the same objects (the fixed point).
2. **All of ix**: every program of ix compiled by mini-ml.

And, on the way, **new constructs where they shorten ix's code**, the
census's idioms (below): bit-field patterns, a deriving of printers,
`type t = _`. Those are not OCaml, so they are not mini-ml's but a
layer of their own, **mlpp** (`languages/ml/pp/`), whose output is
OCaml: `mini-ml -pp`.

## Principles

Those of [`../README.md`](../README.md) and of `plan_ml.md`, and five
of their own:

- **Rewrite ix before porting to mini-ml** (the author). An OCaml
  feature ix uses is implemented in mini-ml when it is cheap (the
  lexer's or the parser's) or when rewriting it away would make ix's
  code worse; otherwise ix's code is rewritten into the subset.
- **Two tools, split by one question: is it OCaml?** mini-ml compiles
  OCaml, a subset of it: what ocaml-light has, and the OCaml ix's code
  uses that is cheap to add (decisions 4 to 6, 8). What OCaml doesn't
  have, the bit fields, `type t = _`, a built-in deriving, later type
  classes, is **mlpp**'s, a layer of rewrites in its own directory:
  ML++ in, OCaml out (decision 7). So mini-ml's compiler stays
  ocaml-light's twin, and mlpp's constructs work with every
  compiler of ix's code: OCaml's through dune, and mini-ml.
- **ix stays OCaml.** ix is built by dune and OCaml today, and will be
  until the bootstrap is done. Every new construct uses a syntax
  OCaml's parser already accepts (checked, `ocamlc -stop-after parsing
  -dsource`): `type t = _`, an extension node `[%bits "..."]`, an
  attribute `[@@deriving show]`. So an editor's coloring, ocamlformat,
  merlin and dune's parsing keep working (the author: "We do want our
  syntax coloring in our classical editor tools to still work"), and
  mlpp (decision 7) turns them into plain OCaml. A construct to come
  keeps to that rule, even where it reads less naturally (type
  classes, Later).
- **Sugar first.** mlpp's first constructs are rewritten on the tree,
  before any type: mini-ml's Scope, Typing and Lower don't change, and
  types stay forgotten after checking (`plan_ml.md`, decision 4). A
  construct that needs the types, type classes, is later's, and stays
  mlpp's (Later).
- **One implementation of each rewrite**: mlpp's, not a second one as
  a ppx for OCaml, and not a third in mini-ml.

## The census

Counted with `languages/ml/tests/ix_features.py` (regexps over the
files git knows, comments and strings removed: close, not exact),
2026-09-30, over all of ix (497 files, 62,000 lines) and over mini-ml's
closure, what its binary links from ix: `languages/ml`, `lib_core`,
`assembler/{Asm,Lexer,Parser,CLI}` (74 files, 5,162 lines).

### The OCaml beyond the subset

| feature | ix: uses (files) | mini-ml's closure | decision |
|---|---:|---:|---|
| labeled arguments `~x` | 1,519 (135) | 48 (11) | mini-ml, erasable ones (decision 5) |
| optional arguments `?x` | 126 (52) | 5 (4) | rewrite |
| record punning `{ x; y }` | 423 (74) | 5 | mini-ml, parser |
| polymorphic variants | 360 (35) | 38 (8) | rewrite: declared variants |
| inline records `C of { ... }` | 198 (16) | 0 | mini-ml (decision 6) |
| object types `< Cap.x; .. >` | 109 (70) | 22 (14) | mini-ml (decision 4) |
| coercions `:>` | 32 (10) | 0 | mini-ml, with the object types |
| `match ... \| exception` | 97 (47) | 15 (5) | mini-ml, parser |
| local open `M.( )`, `let open` | 84 + 3 | 1 | mini-ml, Scope |
| `_` in a type, `{ x; _ }` | 46, 162 | 1, 17 | mini-ml, parser |
| `{\| ... \|}`, `'\xc2'` | 27, 5 | 2, 2 | mini-ml, lexer |
| attributes `[@...]` | 10 | 0 | rewrite (dropped), or skipped by the parser |
| functors `Set.Make`, `Map.Make` | 3 | 1 (`ssa/Alloc`) | rewrite |
| `lazy` | 7 | 3 | rewrite |
| `exception A = B` | 1 | 0 | rewrite |
| Int32, Int64 | 816 | 51 | runtime (Bootstrap) |
| Unix | 440 (43) | 28 (2, lib_core's Procs) | runtime, for all of ix |
| Alcotest, Testo | 89 (8) | 0 | not compiled by mini-ml: the tests stay OCaml's |

None of GADTs, first-class modules, module types, `include`, `module
rec`, functor definitions or let-operators: ix never uses them.

### The idioms a construct could shorten

`ix_features.py --idioms`, over the 296 `.ml` files (53,248 lines):

| idiom | count | construct |
|---|---:|---|
| a word's fields decoded, `field w lo n`, `bit w n` | 427 | bit-field patterns (decision 2) |
| a word encoded, `lsl` and `lor` on a line | 368 | bit-field expressions (decision 2) |
| `.mli` lines repeated verbatim in the `.ml` (outside `val`s) | 1,897 of 8,752 | `type t = _` (decision 1) |
| printers: `show`/`print`/`dump`/`string_of` definitions | 115 | `[@@deriving show]` (decision 3) |
| S-expression printer clauses, `-> sprintf "(...` | 64 | same |
| `ref` 884, `!x` 2,641, `:=` 1,210 | | not a construct: a non-escaping `ref` is Opti's |
| `Int64.`/`Int32.` calls | 834 | not a construct: a module of operators, and local open |
| lines naming `caps` | 966 | none: explicit capabilities are the design |
| `Error e -> Error e`: 0; `None -> None`: 62 | | let-operators would save little: ix uses exceptions |

The decoders and encoders are in `machine/Arm32.ml`, `machine/Arm64.ml`,
`linker/Arm.ml`, `linker/Arm64.ml`, `tiny/TinyAssembler.ml`,
`tiny/TinyLibArm.ml`, `tiny/TinyMachinePi.ml`, and the device drivers'
registers (`kernel/9pi/devices/storage/arm/Emmc.ml`,
`raspberry/Dwc2.ml`, `raspberry/Sdhost.ml`).

## Decisions

### 1. `type t = _`: the `.ml` takes a type from its `.mli`

(The author: "we want the .mli to be the clean exposed API so better to
have the full type defined in there".) In a `.ml`, `type t = _`
declares `t` exactly as its own `.mli` does, its parameters,
constructors and labels:

```ocaml
(* Asm.mli *)
type shift = { reg : int; kind : shift_kind; by : shift_by }
(* Asm.ml *)
type shift = _
```

- A group `type a = _ and b = _` takes the `.mli`'s group; a `_` in a
  group whose other members are written out is an error, as is `_`
  for a type the `.mli` declares abstract (the `.ml` must say what it
  is) or doesn't declare.
- `'a t = _`: the parameters, when written, must be the `.mli`'s.
- mlpp parses the sibling `.mli` with mini-ml's parser and replaces
  the `_`s by the `.mli`'s declarations, printed. About 40 lines.
- OCaml's parser reads `type t = _` (a type whose manifest is a type
  variable), and its type checker rejects it: without mlpp, an error,
  not a wrong program.
- Saves most of the 1,897 repeated lines: one line stays per type.

### 2. Bit-field patterns and expressions

The construct most specific to ix, a toolchain and its emulators.
`machine/Arm32.ml`'s decoder today:

```ocaml
| 0 when field w 4 4 = 0b1001 && field w 23 2 = 1 ->
    Mull { cond; s = bit w 20; signed = bit w 22; acc = bit w 21; rdhi = rn; rdlo = rd;
           rm = field w 0 4; rs = field w 8 4 }
```

With a pattern written as the architecture manual draws the encoding,
the most significant bit first:

```ocaml
| [%bits "c:4 000 01 signed:b acc:b s:b rdhi:4 rdlo:4 rs:4 1001 rm:4"] ->
    Mull { cond = conds.(c); s; signed; acc; rdhi; rdlo; rm; rs }
```

and the same syntax as an expression, for the encoders:

```ocaml
(* linker/Arm.ml today *)
(0xe lsl 24) lor (0x9 lsl 20) lor (0xf lsl 12) lor (1 lsl 8) lor (1 lsl 4)
(* with it *)
[%bits "0000 1110 1001 0000 1111 0001 0001 0000"]
```

- **The fields**: `name:n`, n bits bound to `name`; `name:sn`, the
  same sign-extended (a branch's `imm24:s24`); `name:b`, one bit as a
  bool; a run of `0`/`1`, bits
  that must be those (its width its length); `x` in a run, a bit that
  doesn't matter (`1xx0`); `_:n`, n bits that don't matter. The
  widths must add up to 32; `[%bits16 "..."]` and `[%bits64 "..."]`
  for the others (to settle: which are needed, the Pi's registers are
  32 bits).
- **As a pattern**, on an integer: rewritten to a variable, a guard and
  `let`s, the fixed bits tested field by field (`(w lsr 23) land 3 =
  1`), before the clause's own guard, and the fields bound before it,
  so a `when` can use them. Field by field, not one mask: every
  constant stays below 2^30, the same under js_of_ocaml's 32-bit
  integers (`machine/Bits.mli`: nothing in `machine/` may compare a word
  above 2^31 without its functions). Merging the tests into one mask is
  an optimization for later, switchable.
- A clause binds only the fields its guard or body names (a word, not
  a label after a dot): OCaml's unused `let` is an error in dune's
  default profile. A field named only as a record's label (`{ rd = x }`)
  would still be bound, and warned about: rename it, or write `_:n`.
- **As an expression**: the fields shifted and `lor`ed, each `land`ed
  to its width first; `x` and `_` are errors there.
- The payload is a string, not OCaml syntax, so that it reads like the
  manual; the rewrite parses it (its own small lexer, about 40 lines)
  and reports an error at the string's line. The cost: an editor
  colors it as a string, its field names not as variables.
- Where it comes from: `[%name payload]` is OCaml's *extension node*
  (4.02), the grammar's slot for preprocessors (ppx_let's `let%bind`,
  ppx_sexp_conv's `[%sexp_of: ...]`, MirageOS's `[%%cstruct ...]`).
  The closest existing one is ppx_bitstring (Richard Jones's
  `bitstring`, first a camlp4 extension, after Erlang's bit syntax),
  `match%bitstring p with {| version : 4; hdrlen : 4; ... |}`, on byte
  buffers with endianness; the name `bits` and the payload are mlpp's,
  for a 32-bit word in an int, as the ARM manual draws it. To
  consider: `match%bits w with`, OCaml's sugar for an extension on a
  whole `match`, instead of one per clause.
- About 150 lines in mlpp. Converted first: `machine/Arm32.ml`'s
  decoder, whose tests (`machine/tests`) say whether it still decodes
  the same; then `linker/Arm.ml`'s encoder, and the rest of the list.

### 3. A poor man's deriving: `[@@deriving show]`

A type declaration followed by `[@@deriving show]` gets, right after
it, a printer per type of the group, found from the declaration's
syntax alone, no types needed:

```ocaml
type ty = Tvar of string | Tarrow of ty * ty | Tconstr of longid * ty list
[@@deriving show]
(* adds *)
let rec show_ty = function
  | Tvar a -> "(Tvar " ^ show_string a ^ ")"
  | Tarrow (a, b) -> "(Tarrow " ^ show_ty a ^ " " ^ show_ty b ^ ")"
  | Tconstr (a, b) -> "(Tconstr " ^ show_longid a ^ " " ^ show_list show_ty b ^ ")"
```

- The output is an S-expression, as ix's hand-written dumps (`Ast.show`
  and the other `-d` flags): `(C a b)`, `{(l v) ...}` for a record,
  `[a b]` for a list.
- A type `u` in a component is printed by `show_u`, `M.u` by
  `M.show_u`, a parameter `'a` by a function argument: `show_t show_a`.
  `int`, `string`, `char`, `bool`, `list`, `option`, `array` and tuples
  by a few functions in a module mlpp's output calls (`Show`, about 20
  lines, in `lib_core/`).
- Where a hand-written printer's output is compared by tests, it
  stays, or the tests' outputs are updated on purpose: a printer is
  replaced by a derived one only when the diff is read.
- Later, if the numbers justify it: `[@@deriving map]` for the
  rebuilding clauses (`| Eseq (a, b) -> Eseq (f a, f b)`, about 120 in
  `database/Dbm.ml`, `ssa/Ssa.ml`, `Scope.ml`, `languages/c/`).
- About 120 lines in mlpp.
- ppx_deriving reads the same attribute: a library using both would
  derive `show` twice. ix doesn't use ppx_deriving.

### 4. Capabilities: object types as phantom rows

ix's capabilities (`Cap`, a library of the author's) are object types
used only as types: no method is called anywhere in ix, and the
powerbox's methods all return `()`. So mini-ml needs object *types*,
`< Cap.open_in; Cap.stdout; .. >`, their abbreviations (`type caps = <
Store.caps; Cap.fork >`), `:>` to a named one, and `object method m =
() ... end` only for `Cap.powerbox`, compiled to `()`.

- In Typing: rows (Rémy): a closed row, an open one (`..`, a row
  variable), unification of rows; `:>` checks the source has at least
  the target's methods. About 120 lines.
- A first step, for the bootstrap only: object types parsed, and any
  two unified. Unsound, and the soundness is the capabilities' point,
  so only while OCaml still checks the same code.
- Rewriting them away is not an option: explicit capabilities are
  ix's design (global conventions).

### 5. Labels: erasable ones only

A labeled argument given in the order of the function's parameters,
all of them given, is a positional one with a name: mini-ml parses the
labels, checks them against the function's type when Typing is on, and
erases them. What needs the type to be compiled, labels given out of
order and optional arguments omitted, is rewritten in ix:

- labels out of order or partial: reordered at the call (to count
  first, phase 0: the census counts labels, not their orders);
- optional arguments (126): an explicit `option`, or two functions;
- the labels stay in mlpp's output, which OCaml type-checks.

### 6. Inline records: in mini-ml, not rewritten

Rewriting `C of { rd : int; ... }` as `C of c` with a record type `c`
would be a small change, but ix's inline records share their labels
(`rd` in 49 of them, `rn` 46, `cond` 34, in the ARM instructions'
types), and mini-ml resolves a label as OCaml 1.07 does, by the last
type declared with it. So mini-ml supports them: a constructor's
labels are its own, found from the constructor (Scope), with the
tuple's layout (a block tagged by the constructor). About 60 lines.

### 7. mlpp: ML++ in, OCaml out, as `mini-ml -pp`

`mini-ml -pp file.ml` prints the file as OCaml: its text as it is, but
for mlpp's constructs, rewritten, and lines `# n "file.ml"` where the
rewritten text moves the source's lines, so that ocamlopt's errors name
the source's lines and columns (the author: "we will probably want to
output some #line so that ocamlopt can then report error at the right
place in the original ml file"). dune runs it on the libraries that use
the constructs:

```
(preprocess (action (run mini-ml -pp %{input-file})))
(preprocessor_deps (glob_files *.mli))
```

- **The text, not a printer of the tree.** The first draft printed the
  whole tree back; the text rewritten in place is shorter (no printer
  of `Ast`), exact (a file comes back byte for byte but for its
  constructs, its comments and columns included), and needs `#` lines
  only after a rewrite. What it needs from the parser is where things
  are, in characters: `Ast.span`, on the constructs and on every
  expression (a `[%bits]` clause's guard and body).
- **The constructs are in the tree** (the author: "why not adding
  extensions directly to the appropriate construct in Ast.ml"):
  `Pextension` and `Eextension` for `[%bits "..."]`, a kind `Hole` for
  `type t = _`, a declaration's `tattrs` for `[@@deriving show]` (after
  the group's last, as OCaml's tree has them). `pp/Pp` walks the tree
  for them; Scope rejects them, so none is compiled by mistake.
- **One binary**: mlpp is mini-ml's library `languages/ml/pp/` (`Pp`,
  `Bits`, `Derive`). Compiling, mini-ml rewrites the text the same way
  and parses the result again (CLI's `parse`), its lexer reading the
  `#` lines: one implementation for both.
- A file mini-ml doesn't parse is its own output, so that dune can
  run `-pp` on a whole library while some of its files are still
  outside the subset; with a warning when its text has a construct's
  mark (`[%bits`, `[@@deriving`, a line `type ... = _`, even in a
  string): OCaml would reject the construct, but mini-ml's syntax error
  says why. Attributes that aren't mlpp's
  (`[@@unboxed]`) are left in the text, for OCaml.
- Every addition to mini-ml for mlpp is marked `(* mlpp: ... *)` (the
  author: "so it's clearly marked in the file").
- **Its tests** (`languages/ml/tests/pp.sh`): every `.ml` and `.mli` of
  ix comes back unchanged; `pp/`'s programs, rewritten and compiled by
  OCaml, print their `.out`, and, with `MINI_ML=1`, compiled by mini-ml
  (`run.sh 7`) too; `pp/errors/`'s files get from OCaml the error their
  first line expects, at the source's line and columns.
- `languages/ml/`, `-pp`'s own source, doesn't use mlpp's constructs
  (dune would need mini-ml to build mini-ml).
- **The editors' tools** (checked 2026-09-30, OCaml 4.14, ocamlformat):
  the three constructs parse, and ocamlformat keeps them as written
  (the payload string untouched, so a diagram's layout stays). Without
  `-pp`, OCaml rejects them, never miscompiles them: `[%bits]` is an
  uninterpreted extension, `type t = _` "The type variable _ is unbound
  in this type declaration", and `[@@deriving show]`, an attribute
  OCaml ignores, gives `Unbound value show` where the printer is used.
  With `-pp`, merlin (ocaml-lsp) should see the rewritten code, and
  through its `#` lines point into the source: a `[%bits]` clause's
  fields known in its body, a `type t = _`'s constructors leading to
  the `.mli`, where they are declared, a derived printer to its
  attribute's line. **Not checked yet**: that merlin runs a dune
  `(preprocess (action ...))`, not only a ppx (older dunes didn't);
  checked on the first library wired (phase 1). If it doesn't, mlpp
  also packaged as a ppx-style driver, the same rewrite behind
  ppxlib's interface.

### 8. The cheap sugar

In the lexer and the parser, each rewritten into the subset:

- record punning, `{ x; y }` in expressions and patterns, `{ x; _ }`;
- `{| ... |}` strings, `'\xNN'` characters;
- `match e with p -> a | exception E -> h`, as
  `(try let v = e in fun () -> match v with p -> a with E -> fun () -> h) ()`,
  so that an exception of `a` is not caught; the closure's cost is
  Opti's to remove, later;
- `_` in a type, as a fresh type variable;
- local open `M.(e)` and `let open M in e` (in Scope);
- `let*` and `and*`, as applications of `( let* )`: cheap, but the
  census says ix would use them little.

About 120 lines in all.

### 9. The bootstrap

mini-ml's closure, once decisions 4, 5 and 8 are in, and the rewrites
done in its 74 files (38 polymorphic variants, one `Set.Make`, 5
optional arguments, 3 `lazy`):

- **The stdlib**: ocaml-light's, extended for ix, has 112 of the 134
  functions the closure calls; the 22 others (`Bytes.get_int64_le`,
  `String.index_opt`, `List.sort_uniq`, `Lexing.lex_curr_p`...) are
  written, about 100 lines.
- **The libraries**: `caps` (392 lines, compiled, with decision 4);
  `fpath` (781 lines, of which mini-ml calls 11 functions) and `logs` and
  `fmt` (1,136 lines, on Format) replaced, for this build, by an
  `Fpath` of those 11 functions (about 60 lines) and a `Logs` that
  prints (about 30).
- **The runtime**: `runtime.c` has 64 externals that fail when called.
  The closure needs Int64's (boxed on arm; mini-ml's 64-bit
  constants), and `lex_engine` and `parse_engine`, the automata of
  ocamllex's and ocamlyacc's tables, which mini-ml's own Lexer and
  Parser run on (ocaml-light's `lexing.c` and `parsing.c`, about 500
  lines of C, ported), and the positions `Lexing.new_line` and
  `Parsing.symbol_start_pos` read.
- **The fixed point**: stage 1, mini-ml built by OCaml, compiles
  mini-ml: stage 2; stage 2 compiles mini-ml: stage 3; stage 2's and
  stage 3's objects must be identical, and stage 2 must pass mini-ml's
  tests.

## Status

- **2026-09-30, phase 1, and a first version of phases 3 to 5 and of
  decision 4.** `mini-ml -pp` (decision 7); `[%bits "..."]` as a
  clause's pattern and as an expression (decision 2, `pp/Bits`), an ARM
  multiply long, a branch and clrex decoded and encoded back
  (`tests/pp/bits.ml`); `type t = _` and `[@@deriving show]` (decisions
  1 and 3, `pp/Derive`: `tests/pp/shapes/`); both compiled by OCaml and
  by mini-ml (arm64, `ML_HEAP=64` too), with the same output. Derived
  printers print strings with `String.escaped`, not `%S`, which
  ocaml-light's printf lacks. Object types parsed, all one type in
  Scope, and `(e :> t)` the identity (decision 4, its first step):
  237 of ix's 497 files don't parse, from 260. Not yet: the cheap
  sugar (phase 2), a library built by dune through `-pp`, `machine/`'s
  decoder converted (it doesn't parse yet: labels, punning).

## Phasing

0. **The census**: `ix_features.py`, `parse_ix.sh` (done, 2026-09-30).
   To add: labels given out of order or partially, and optional
   arguments omitted (decision 5).
1. **mlpp's skeleton** (decision 7): `mini-ml -pp` printing a file
   back, its test over ix's files (done); dune wired on one library,
   and merlin checked on it (decision 7, "The editors' tools").
2. **The cheap sugar** (decision 8); `parse_ix.sh`'s count going down.
3. **mlpp's `type t = _`** (decision 1), then applied: the 1,897 lines.
4. **mlpp's bit fields** (decision 2): `machine/Arm32.ml`'s decoder first, then
   the encoders and the drivers.
5. **mlpp's deriving** (decision 3): the new printers first, then the
   hand-written ones whose diffs are read.
6. **The bootstrap** (decision 9): the rewrites in the closure, the
   phantom rows, erasable labels, the stdlib's functions, the libraries'
   replacements, the runtime's engines; the fixed point.
7. **All of ix**: directory by directory, the rewrites, inline records
   (decision 6), rows done properly (decision 4), Int64 and Unix in the
   runtime; the tests stay OCaml's.

## Later: mlpp beyond sugar

mlpp is where ix's ML can grow past OCaml without mini-ml's compiler
growing:

- **Type classes**, single-parameter, over types (`'a show`, `'a eq`,
  `'a num`), compiled by passing dictionaries: a class a record type,
  an instance a value of it, a constrained function one more argument.
  Their syntax must be OCaml's (Principles): not `class show 'a =
  ...`, which OCaml parses as a class of objects, but an extension
  (`[%%class ...]`) or attributes on a record type, which read less
  naturally. They make the meaning depend on the types, so mlpp needs
  the types: it runs mini-ml's Scope and Typing, extended with constrained type
  schemes and instances, then rewrites the tree; mini-ml's own Typing,
  after the rewrite, checks it for free. About 700 lines. Not
  classes over type constructors (Monad, Functor): their dictionaries
  aren't ML types (no higher kinds, no polymorphic fields in
  ocaml-light). In ix they would mostly give `show` (decision 3 does it
  without types) and arithmetic on Int64: to weigh when decisions 2 and
  3 are in use.
- **`[@@deriving map]`**, and other derivings, when the numbers justify
  them (decision 3).
- Whatever a later census finds: mlpp is the place to try a construct,
  since its output is OCaml, and dropping it means printing that
  output once and keeping it.

## Out of scope

- **Type classes in mini-ml**: they are mlpp's (Later).
- **Functors, first-class modules, GADTs**: ix doesn't use them, except
  3 `Make`s, rewritten.
- **Implicit capabilities**: 966 lines name `caps`, and that is the
  point.
- **Compiling the tests**: Alcotest and Testo stay OCaml's.
