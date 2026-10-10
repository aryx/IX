# Plan: mini-ml compiles ix, and mlpp, the ML beyond OCaml: bit fields, deriving, `type t = [%mli]`, type classes (`languages/ml/`, `languages/ml/pp/`)

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

**Status: done** (2026-10-09; the author, of the plans that read as finished: "ok let's move the easy one to done/ and also plan_ml_bootstrap"), and this file kept as its
record: its two goals reached, mini-ml compiles itself (the fixed
point) and all of ix (249 of 249 files on 2026-10-02), and mlpp's
constructs in use. **"The ledger" stays here and is still kept**: a
line for each change of mini-ml or of ix's code for it, after this
date as before. What is left is listed at the end, "What is left".

## Context

mini-ml compiles ocaml-light's dialect: mini-9pi's kernel is written
in it and parses (135 of `kernels/`'s 136 files). The rest of ix, the
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
| builder, shell, editors | 63 | 51 |
| assembler, linker | 22 | 20 |
| tiny | 16 | 15 |
| lib_core, lib_compression, lib_crypto | 13 | 12 |

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
| `.mli` type declarations of several lines the `.ml` repeats line for line | 273 lines (130 in files mini-ml parses) | `type t = _` (decision 1) |
| printers: `show`/`print`/`dump`/`string_of` definitions | 115 | `[@@deriving show]` (decision 3) |
| S-expression printer clauses, `-> sprintf "(...` | 64 | same |
| `ref` 884, `!x` 2,641, `:=` 1,210 | | not a construct: a non-escaping `ref` is Opti's |
| `Int64.`/`Int32.` calls | 834 | not a construct: a module of operators, and local open |
| lines naming `caps` | 966 | none: explicit capabilities are the design |
| `Error e -> Error e`: 0; `None -> None`: 62 | | let-operators would save little: ix uses exceptions |

The decoders and encoders are in `machine/Arm32.ml`, `machine/Arm64.ml`,
`linker/Arm.ml`, `linker/Arm64.ml`, `tiny/TinyAssembler.ml`,
`tiny/TinyLibArm.ml`, `tiny/TinyMachinePi.ml`, and the device drivers'
registers (`kernels/9pi/devices/storage/arm/Emmc.ml`,
`raspberry/Dwc2.ml`, `raspberry/Sdhost.ml`).

## Decisions

### 1. `type t = _`: the `.ml` takes a type from its `.mli`

**Now spelled `type t = [%mli]`** (2026-10-04, the author: "let's drop
the = _ spelling and use [%mli]"): an extension node, as `[%bits]`, which
says what it is, and which OCaml without mlpp refuses by its name
("Uninterpreted extension 'mli'"). What follows says `= _`, its first
spelling; the rules are the same.

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
  the `_` by the `.mli`'s `= ...`, its lines joined, on the hole's
  line: an error in it, and merlin's go-to-definition of one of its
  constructors, name the `.ml`'s `type t = _` (merlin takes a `#`
  line's line but not its file, so a `#` line to the `.mli` sent it to
  the `.mli`'s line in the `.ml`). About 40 lines.
- OCaml's parser reads `type t = _` (a type whose manifest is a type
  variable), and its type checker rejects it: without mlpp, an error,
  not a wrong program.
- Saves 273 lines in all of ix, 130 in the files mini-ml parses today
  (`ix_features.py --holes`, 2026-09-30): the lines after the first of
  each type the `.ml` repeats. The first census said 1,897, every
  `.mli` line found anywhere in its `.ml` (a `| Foo`, a `}`, a
  comment): wrong by seven times.

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

### 5. Labels: Scope's, erased in the callee's order; no optional arguments

Labels are names resolved before the types, as modules' are: Scope
puts a call's arguments in the order of the callee's parameters, and
nothing after it knows of labels (the author chose it over labels only
in order: "let's do B"). So Typing, Lower and the back ends don't
change, and decision 4 of `plan_ml.md` holds.

- **A function's labels** (`Scope.params`: `Some l` or `None` per
  parameter) are known from its definition (`let f ~x y = ...`, `let
  rec`), its type (a `val` of a `.mli`, a record's field, a parameter's
  annotation `(f : x:t -> u)`), another name of it (`let g = f`), or
  what a call leaves of it (`let g = f ~x:1`).
- **A call**: an argument with a label goes to the first free
  parameter of that label, another to the first free one without;
  those beyond are the result's. OCaml's exception is kept: no label
  at all and every parameter given, in order.
- **Refused**: a parameter not given while a later one is (`f ~y:2`
  when `~x` is before: OCaml makes it a function of `x`; here, written
  as one in ix); a label the function hasn't.
- **Refused too: a label for a function Scope knows no label of**, a
  function that is a value (a parameter, an `if`'s result, a table's
  element): only its type says its arguments' order. The other way was
  labels kept in the types and checked by Typing (40 to 50 lines); the
  author: "what if instead we forbid such function like apply?", then
  "I like to require to annotate more in order to simplify the
  typechecker. It's something we should do more often, especially
  because types are useful documentation that people write anyway,
  especially for toplevel functions". So the parameter is annotated,
  `(f : from:int -> by:int -> int)`, and Scope has its labels; the
  types have none, and the rule holds without the type checker
  (`-unsafe-types`). In ix: mini-qemu's `loop`, whose `~qmp_poll` is
  called `qmp_poll q ~quit`; and, until mini-ml's stdlib declares them
  with their labels, `Option.value ~default` and `String.starts_with
  ~prefix` (5 files).
- A principle with it: where a construct needs the type checker to
  infer more, ix's code says the type instead.
- **When a label is wanted** (the author): "labels are good when a
  function take a bool where true at call site is unclear, or a
  function that takes multiple times the same type, where ~x: ~y:
  helps". So the stdlib's kept in ix: `String.starts_with ~prefix`
  and `ends_with ~suffix` (two strings), `Fun.protect ~finally` (two
  functions), `Unix.pipe ~cloexec:true` (a bool; a required label in
  mini-ml's Unix); and not `Option.value o ~default:d` (an option and
  a value: "I never liked it"), now `o ||| d`, xix's operator, in
  `lib_core/Common` (opened where used: explicit, "we can always
  refine later"; a dune `-open Common` would be no line in the files).
- The arguments' evaluation order is the parameters', as OCaml's
  (checked: `tests/modern/labels.ml`'s third line).

**Optional arguments: gone from ix** (2026-09-30). The author: "I've
always been confused with the ? in ocaml ... it's too tricky", then,
after four pilots: "let's rewrite then and remove the use of '?'
across all of ix". The tricks mini-ml would have had to copy: an
omitted one is filled only when a later positional argument is given,
`?x:` passes an option where `~x:` passes a value, the type is
`?x:int` outside and `int option` inside, and a function with one
passed to `List.map` fixes it silently. None of ix's 45 needed that:
each became a choice written in the code, and none read worse.

- **Two functions**, when one case is the common one: `Files.write`
  and `write_perm caps 0o755`; C's `tcom` and `tcomo ~addr` (5c's own
  names), `complex` and `complex_ret`, `Tree.mk` and `mk_typed t`;
  `Zlib.inflate` and `inflate_at`, `crc32` and `crc32_sub`; mini-ml's
  `unify` and `unify_what`, `show` and `show_with`; the test helpers'
  `mkfile`, `world`, `build` and their `_with`.
- **A required label**, when both cases are common or the value is
  computed: `Conf.lookup ~all`, `Mkfile.read ~override`,
  `Archive.time ~force`, `Outofdate.arc ~eval`, `Diff.output ~header`,
  `Mmu32`'s `result ~keep`, `Devices.regs ~fixed`.
- **An `option` in the type**, when absent means something:
  `Cpu.run32 ~trace`, `Build.create ~hashes`, `Recipe.env ~job`,
  `Arm64.take ~esr ~far`, the linkers' literal `pool`.
- A parameter never passed: `mem ?(off = 0)` in the linkers had 5 calls
  with `~off`, now `mem_off`; `assemble ?name` in `TinyLibCPU`, dropped.

Checked: `make test`, `make test-goken`, mini-ml's `types.sh`, `pp.sh`
and `run.sh`, the C compiler's listings (identical to 5c's and 7c's)
and `simple.sh` (its one failure, `mem`, fails at the commit before
too).

### 6. Inline records: in mini-ml, a record of the constructor's own

Rewriting `C of { rd : int; ... }` as `C of c` with a record type `c`
was tried in ix and reverted: +212 lines, and each instruction's fields
away from its constructor in `Arm32.mli`. So mini-ml does that rewrite
itself, in Scope, and ix's source keeps its inline records.

- **A type of its own**: for `C of { ... }` in a type `t`, Scope
  declares a record type `t.C`, with `t`'s parameters, and `C` is a
  constructor of one argument of that type. Typing and Lower see a
  constructor and a record: nothing of theirs changes.
- **The labels are the constructor's** (`cons.cinline`), not the
  environment's: ix's inline records share theirs (`rd` in 49, `rn`
  46, `cond` 34, the ARM instructions'), and mini-ml takes a label, as
  OCaml 1.07, from the last type declared with it. So `C { rd = e }`
  and the pattern `C { rd; _ }` look `rd` up in `C`'s record; and a
  name a pattern `C r` binds remembers `C` (`var_inline`), for `r.rd`,
  `r.rd <- v` and `C { r with rd = e }`.
- **The price**: where OCaml puts the fields in `C`'s block, `C`
  points to the record's, one allocation and one indirection more.
  The behavior is the same (equality, order, mutation); the fields in
  the constructor's block is an optimization for later, Lower's.
- Not `exception E of { ... }`, which ix doesn't have.

### 7. mlpp: ML++ in, OCaml out, as `mini-ml -pp`

`mini-ml -pp file.ml` prints the file as OCaml: its text as it is, but
for mlpp's constructs, rewritten, and lines `# n "file.ml"` where the
rewritten text moves the source's lines, so that ocamlopt's errors name
the source's lines and columns (the author: "we will probably want to
output some #line so that ocamlopt can then report error at the right
place in the original ml file"). dune runs it on the libraries that use
the constructs:

```
(preprocess (action (run %{bin:mini-ml} -pp %{input-file})))
(preprocessor_deps (source_tree .))
```

`%{bin:mini-ml}` is the workspace's mini-ml, which dune builds first,
not one on the PATH (the author: "this assumes mini-ml is already
built and installed in the path?"). `(source_tree .)`, the directory's
source files, gives a `.ml`'s rewrite its `.mli` (`type t = _`); not
`(glob_files *.mli)`, which also matches dune's `x.pp.mli`, the `.mli`
rewritten, and makes a cycle. First wired: `tests/pp/shapes/`, an
executable that `dune build` builds.

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
  attribute's line. **Checked** (2026-09-30, `ocamlmerlin` on
  `tests/pp/shapes/shapes.ml`): dune gives merlin `-pp "mini-ml -pp"`,
  and merlin runs it on a copy of the editor's buffer,
  `/tmp/merlinppXXXXXXshapes.ml`, in the source's directory: so
  `-pp`, not finding `/tmp/merlinppXXXXXXshapes.mli`, takes
  `shapes.mli` there (CLI's `rewrite`). Then no error, a type on hover,
  and go-to-definition of a constructor of a `type t = _` or of a
  derived printer to its line.

### 8. What mini-ml parses of today's OCaml, and what ix gave up

Goal 1 first (the author: "let's just add the parsing code for now"):
every `.ml` and `.mli` of ix parsed. The author judges each construct:
in mini-ml, or rewritten out of ix. Done 2026-10-01: +131 lines in
mini-ml, and all of ix's 512 files parse (`parse_ix.sh`; 275 did):

- **compiled too**, rewritten by the parser into the subset: record
  punning, `{ x; y }` in expressions and patterns, and `{ x; _ }`;
  `{| ... |}` strings; `'\xc2'` and `"\x7f"`, bytes in hexadecimal as
  the formats' specifications write them (the author: "are the hexa
  more readable?", then "let's support \x in the lexer"); `match e with
  p -> a | exception E -> h`, as `(try let v = e in fun () -> match v
  with p -> a with E -> fun () -> h) ()`, so that an exception of `a`
  is not caught (the closure's cost Opti's to remove, later); `_` in a
  type, a variable of its own; attributes other than `[@@deriving]`,
  skipped by the lexer (OCaml reads them in `-pp`'s output, the text);
- **parsed, and refused by Scope until goal 2** ("parsed, not compiled
  yet"): labels `~x`, `~x:e`, `x:t ->` (decision 5); inline records
  (decision 6); local open `M.(e)`; `3L` and `3l`, int64 and int32
  literals (303 and 10 uses: the arm64 emulator's registers, the C
  compiler's `vlong`s; a pattern `| 0L ->` and a constant too wide for
  an `int` have no other writing; `l` "for consistency with Int64");
- **rewritten out of ix**: optional arguments (decision 5),
  polymorphic variants, `Set.Make`, `lazy`, `exception A = B`, `let
  open M in` (2, now `M.( )`), and what the last 19 files had (the
  author: "I think we should rewrite all the cases above"): `for _ =
  ...`, now `for _i` (10); a log's source, `let src = Logs.Src.create
  ...` and its first-class module `(val Logs.src_log src : Logs.LOG)`,
  now plain `Logs.debug` (3 files: "each program is run independently
  so we can use Logs.xxx everywhere", and `~src` is an optional
  argument, which a Logs of mini-ml's own couldn't take); `Unix.[ ... ]`, now `Unix.([ ... ])` (2); array
  patterns, on `Sys.argv`, now a list's (5); the `'a.` of Scope's
  `lookup`, a polymorphic function in a recursive definition, split in
  the recursive `qualified` and `found` outside it; the method types
  ocaml -i had written in `languages/c/CLI.mli`, now `< caps; .. >`;
- not `let*`: ix has none, and wouldn't use them (the census).

### 9. The bootstrap

mini-ml's closure, once decisions 4, 5 and 8 are in, and the rewrites
done in its 74 files (38 polymorphic variants, one `Set.Make`, 5
optional arguments, 3 `lazy`):

- **The stdlib: ix's, in `lib_core/`** (the author: "let's copy, so
  no dependency on /tmp/"; and its place, "why not under
  lib_core/stdlib/", then "we might want to split things like I did
  in ~/xix/lib_core/ with those core base commons etc. I think it was
  cleaner"). ocaml-light's 41 modules (its commit f397c6bf: 79 files,
  10,074 lines with their interfaces' comments), their names
  capitalized, in xix's directories: `core/` (Pervasives, Obj,
  Marshal, Gc...), `base/` (String, Bytes, Int64, Option...),
  `collections/` (List, Array, Hashtbl...), `printing/`, `parsing/`,
  `system/`; `lib_core/units.txt` has their order. ix's own modules
  are `lib_core/commons/`, the `ix_core` library, the only directory
  of them dune builds: the programs dune builds have OCaml's stdlib.
  xix's layout, not its contents: of the 331 functions of the stdlib
  ix uses, ocaml-light's has 225, xix's fewer (no Int64, no
  `List.concat_map`). To add, each in its directory: the 106 others
  (Bytes 21: `get_int32_le`...; String 16: `contains`, `index_opt`...;
  Int64 11: `compare`, the floats' bits...; `In_channel`,
  `Out_channel`, `Seq`), `format4`, `%C`, the labels of
  `String.starts_with`, `ends_with` and `Fun.protect`.
- **The C under it, later** (the author): "we should probably at some
  point also move the C code needed under lib_core/libc/ or something
  (taken from goken or principia, we'll see later); the mini-ml C
  runtime can then depends only on this lib_core/libc/". Today
  `run.sh` builds goken's libc from `~/goken`.
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
  237 of ix's 497 files don't parse, from 260. Then dune: a program
  built through `%{bin:mini-ml} -pp` (`tests/pp/shapes/`), and merlin
  on it (decision 7): `-pp` finds the `.mli` of merlin's copy of a
  buffer, a `type t = _` gets its `.mli`'s text on its own line, and a
  derived printer's `let` is `rec` only for a recursive type (dune's
  default profile makes an unused `rec` an error). Not yet: the cheap
  sugar (phase 2), `machine/`'s decoder converted (it doesn't parse
  yet: labels, punning).

## The accounting

Two goals weigh what mini-ml gains: the lines mlpp's constructs save
elsewhere in ix, and compiling ix with mini-ml (the author: "The goal
is to add features in mini-ml that ultimately will save lines in other
parts of the project", "and also to be able to compile ix with
mini-ml"). The tests aren't counted (the author).

Added to mini-ml, 2026-09-30 (`git diff 2b8250b 92c9b4e`, without
`tests/`): 726 lines, 25 removed; of code, without comments and
`.mli`s, 454: `pp/` 335 (Pp 180, Bits 79, Derive 76), the rest 119
(Parser, Lexer, Ast, Scope, CLI), about 20 of them for the object
types, which serve the second goal.

Saved so far: none; no file of ix uses the constructs yet. To save,
measured or guessed:

| construct | lines | how known | reachable today |
|---|---:|---|---|
| `type t = _` | 273 | measured (`--holes`) | 130 |
| `[%bits]` | 150 to 250 of the ~800 lines of shifts and masks | guessed | none: the decoders don't parse |
| `[@@deriving show]` | 100 to 300 of the 115 printers | guessed | where a printer's output may change |

### The ledger

Kept as the work goes (the author: "let's keep track of those
statistics summary as we go"): each change, its lines of code, net,
without tests and docs (`git diff --numstat` against the commit before
it; a new file its `wc -l`). mini-ml's own lines count as added; the
features ix is rewritten out of are what mini-ml doesn't have to grow.

| date | change | in mini-ml | in ix | what it avoids in mini-ml |
|---|---|---:|---:|---|
| 2026-09-30 | mlpp: `-pp`, `[%bits]`, `type t = _`, deriving (`2b8250b..92c9b4e`) | +701 | 0 | |
| 2026-09-30 | object types parsed, one type (in the same commits) | ~+20 | 0 | |
| 2026-09-30 | no `?`: 45 definitions rewritten (decision 5) | | +54 | optional arguments, ~150 |
| 2026-09-30 | no polymorphic variants: regular variants, 35 files | | +67 | row types, ~100 |
| 2026-09-30 | `lib_core/Json` for Yojson's variants (mini-qemu's QMP); yojson dropped | | +155 | |
| 2026-09-30 | no `Set.Make`: `lib_core/Set_` (the author's, from the stdlib's `Set`, polymorphic) | | +475 | functors, ~150 |
| 2026-09-30 | no `lazy` (Zlib, the tiny machines eager; Scope's own memo), no `exception A = B` | | +6 | `lazy` ~30, aliases ~10 |
| 2026-09-30 | inline records rewritten, then reverted: mini-ml gets them (+212 in ix against ~70 in mini-ml) | | 0 | |
| 2026-10-01 | goal 1's parsing (decision 8): labels, inline records, `M.( )`, punning, `{\| \|}`, `\x`, `match \| exception`, `_` types, `3L` `3l`, attributes skipped | +131 | -2 (`let open`) | |
| 2026-10-01 | the last 19 files' constructs rewritten (decision 8): `for _`, the logs' sources and first-class modules, `Unix.[ ]`, array patterns, `'a.`; all 512 files parse | +2 (Scope's `found`) | -16 | each a parser's rule or more |
| 2026-10-01 | goal 2, step 1: local open `M.(e)` compiled (Scope: M's names in front, as `open`'s); `tests/modern/` | +1 | 0 | |
| 2026-10-01 | goal 2, step 2: `int64` and `int32`: the names of `Int64.t` and `Int32.t`, `3L` and `3l` as static blocks, the runtime's 34 primitives (boxed, two tags, compared and hashed by value; no custom blocks: notes_ml.md, §11) | +126 (the runtime +97) | 0 | |
| 2026-10-01 | goal 2, step 3: labels, a call's arguments put in the callee's parameters' order by Scope (decision 5) | +101 | 0 | labels in the types, ~250 |
| 2026-10-01 | a label for a function Scope knows no label of: refused, the function's type written (decision 5), not labels in Typing | +9 | 0 | labels in the types, 40 to 50 |
| 2026-10-01 | no `Option.value ~default`: `\|\|\|`, `lib_core/Common` (xix's), 73 calls; `open Common` in 39 files, the operator's line in 5 that stand alone | 0 | +104 (edits +85, `Common` +19) | a label's declaration in the stdlib |
| 2026-10-01 | goal 2, step 4: inline records, a constructor's one argument a record of a type of its own, its labels the constructor's (decision 6) | +49 | 0 | (the rewrite in ix was +212) |
| 2026-10-01 | goal 2, step 5a: the stdlib in ix, `lib_core/{core,base,collections,printing,parsing,system}/`, ocaml-light's as it is; ix's modules to `lib_core/commons/` (decision 9) | 0 | +10,074 (79 files copied; +50 its dune and `units.txt`) | no dependency on /tmp |
| 2026-10-01 | goal 2, step 5b: String, 15 of OCaml's later functions (`contains`, `index_opt`..., `iter`, `for_all`, `init`, the binary fields' `get_int32_le`...) and the labels of `starts_with`, `ends_with`; in ix, `List.of_seq (String.to_seq s)` is `List.init`, 6 | 0 | +61 (the stdlib) | a `Seq` for a string's characters |
| 2026-10-01 | goal 2, step 5b: `Seq`, OCaml 4.14's trimmed to the 11 functions ix uses (of 77), `List.to_seq`, `of_seq`, `Array.to_seq` | 0 | +182 (the stdlib: `Seq` 148, `List` and `Array` 34) | (tiny-database's queries and git's `Query` rewritten without) |
| 2026-10-01 | the stdlib trimmed: `Stream`, `Weak`, `Stdcompat` out (no program of ix names them, nor xix; the runtime's three `weak_` stubs with them). Kept though ix doesn't name them: `Either`, `Lazy`, `Map`, `Set`, `Result` (xix's and osemgrep's). Function by function nothing is worth it: what no program names is the Pervasives' names used bare and the companions (`Int.zero`, `Float.add`) | -3 (the runtime) | -399 | |
| 2026-10-01 | goal 2, step 5b: the stdlib's functions that are plain OCaml, 62: Bytes' binary fields and `copy`, Buffer's (`add_int32_le`..., `truncate`), Queue (`is_empty`, `push`, `pop`, `take_opt`), List (`filteri`, `sort_uniq`, `assq_opt`, `remove_assoc`), Array (`exists`, `for_all`, `mem`, `find_opt`, `sort`), Int64 (`compare`, `unsigned_*`, `of_string_opt`), `int_of_string_opt`, `Filename.quote`, `Digest.to_hex`..., and `In_channel`, `Out_channel`; `Int64.min`, `max` renamed `min_int`, `max_int`; `Fun.protect`'s label; `Bytes.of_string` and `to_string` copy | 0 | +335 (the stdlib: +257 in 14 modules, 78 the two new) | (not rewritten: 300 calls in ix) |
| 2026-10-01 | the stdlib's functions ix called once, rewritten: `Option.fold`, `Hashtbl.filter_map_inplace`, `Filename.quote_command` | 0 | +1 | three functions and `Option.fold`'s two labels in the stdlib, ~15 |
| 2026-10-01 | goal 2, step 5c: the runtime's files, on Plan 9's libc (goken's; POSIX's in `gnu.h`): `sys_open` with its flags (a file read, appended to, made only if absent), `close`, `Sys.file_exists`, `is_directory`, `remove`, `rename` (in a directory), `getcwd`, `command`, and new in Sys `readdir`, `mkdir`, `rmdir`, `executable_name` | +262 (the runtime +170, `gnu.h` +92) | +16 (the stdlib) | |
| 2026-10-01 | goal 2, step 5d: a format's `%ld`, `%Ld` (an int32, an int64, with `%d`'s flags and bases), `%S`, `%C`: Typing's format, and Printf's cases, ocaml-light's own uncommented | +7 | -9 (the stdlib) | (58 uses, 18 files) |
| 2026-10-01 | goal 2, step 5e: floats as OCaml's: a float's bits (`Int64.bits_of_float`, `float_of_bits`, `of_float`, `to_float`, Int32's), `infinity`, `nan`, `max_float`..., `Float.round`, `trunc`, `is_nan`, `min`, `max`; and `=`, `<` IEEE's (a nan equal to nothing): the runtime's six relations, called by the two code generators, `compare` still total; a zero's and a nan's sign kept by `-.`, `abs_float`, `ceil`, `floor`; List's `mem` and `assoc` by `compare`, as OCaml's | +103 (the runtime +95, Lower, Gen, Emit +8) | +83 (the stdlib) | |
| 2026-10-01 | goal 2, step 5f: MD5 in the runtime, for Digest (`string`, `substring`, `file`, `channel`) | +140 (the runtime) | +1 | (the author: "for md5 let's add the 100 lines of C") |
| 2026-10-01 | no `private`: `Sha1.t` is abstract (the author: "remove the type private in Sha1.mli", "not worth it"); no coercion read it as a string, `Sha1.raw` does | 0 | 0 | the keyword, its check of constructions, ~20 |
| 2026-10-01 | no wrapped libraries, no `Ix_asm.` prefixes (the author: "let's also remove those wrapped true and dune library prefixes; I never liked them"): every library `(wrapped false)`, 72 prefixes and 21 `open Ix_...` out, the dune files' `-open` flags too; a module's name is its program's own. Four names were two modules' in one program: the assembler's `Lexer`, `Parser` are `Lexer_asm`, `Parser_asm` (xix's names), its `CLI` a library of its own, mini-cc's compat `Gen` is `Cgen` | 0 | +4 (the dune files' `wrapped false`, against the flags and opens out) | library namespaces in mini-ml (a `-L Ix_asm=dir`, a module's two names), ~40 |
| 2026-10-01 | goal 2, step 6a: type-directed fields, the poor man's (ocaml-light's): `r.l` and `r.l <- v` take `l` in `r`'s type when Typing knows it, a field of another module's type without its module, a field of two types; Scope leaves a field it doesn't find to Typing, which writes its position | +36 | 0 | (2,510 uses in ix; `d.Ast.tname` at each otherwise) |
| 2026-10-01 | goal 2, steps 6b and 6c: type-directed constructors and whole records, the expected type passed down in Scope (`want`), from what is written only: an annotation, a val's type, a field's or a constructor's argument's, an earlier argument's (`k = Commit`, `!r`); nothing inferred. 8 annotations in ix where no type was written; `Open_binary`, `Open_text` in the stdlib | +169 (Scope) | 0 (8 lines annotated) | qualifying 2,700 names in ix; or the expected type through Typing, with its constructors' arities known late |
| 2026-10-01 | goal 2, step 7a: `format4` (a format's fourth type, what the function gives in the end: `ksprintf`'s, and ix's `error : ('a, unit, string, 'b) format4 -> 'a`), `format` its abbreviation; `%h`; a `# 1 "file"` as a file's first line (ocamllex's output) | +16 (Scope, Typing, Lexer) | 0 | |
| 2026-10-01 | goal 2, step 7b: the stdlib's last values: UTF-8 (`String.get_utf_8_uchar`, `Uchar.utf_decode_...`, `Buffer.add_utf_8_uchar`: OCaml's API, 18 lines for the decoder against its 60), `Float.fma` in OCaml (Boldo and Melquiond's, by rounding to odd), `really_input_string`, `set_binary_mode_out`, `Format.pp_print_list`, `( @@ )`, `Bytes.cat`, `concat`, `String.rindex_from_opt` | 0 | +151 (the stdlib) | |
| 2026-10-01 | goal 2, step 7c: `Fpath` and `Cap`, `CapSys`, `CapStdlib` for mini-ml only, in `lib_core/system/`, not dune's (the author: "let's not compile this Fpath with regular ocaml (via dune) for now"; for caps, "let's just 'erase' it"): Fpath's 12 functions ix uses, after Daniel Bünzli's; a capability nothing, its object type one type | 0 | +156 (4 modules) | objects in mini-ml; fpath's 1,400 lines |
| 2026-10-01 | goal 2, step 6d: the expected type, again: an expression's written type read once it is resolved (`type_of`), so a `match`'s, an `if`'s, a `let`'s is its first result's; `[ M.C; C' ]` and `-> M.C \| -> C'` take the first's type; in Typing, a function given where the parameter's type is a function's is checked under it (`(fun r -> r.l)`); `let rec f : t = function` in Lower; `let f : t = fun` generalized. In ix, 13 annotations and 2 rewrites more | +52 (Scope +38, Typing +8, Lower +2, the rest) | 0 (15 lines changed) | |
| 2026-10-01 | goal 2, step 7d: `Logs`, a poor man's, for mini-ml only (the author: "for Logs, we can add a poor's man version, like I did in ~/xix/"), with `Logs_fmt.reporter` and `Fmt.pf`, `stderr`, so that ix's `Logging` is one source: a reporter is a header's printer and a formatter; no sources, no tags | 0 | +115 (3 modules) | first-class modules, a record of polymorphic functions with optional arguments (the real reporter) |
| 2026-10-01 | the expected type: a record written with no type to go by is of the scope's last type that has all its fields, and only them when it is written whole (OCaml's rule: `Link`'s `sym` and `prog` share `version`); in Typing, a function given under its parameter's type through an abbreviation (`'a Logs.msgf`) | +19 (Scope +16, Typing +3) | 0 | |
| 2026-10-01 | goal 2, step 8: `Unix`, for mini-ml only, in OCaml: the 90 names ix uses (files, directories, processes, pipes, time, sockets, `select`, a terminal's settings, a timer), each a system call of Linux's made by one primitive of the runtime, the kernel's structures packed as bytes; `CapUnix` erased. The same with goken's libc and with glibc, the runtime by mini-cc or by gcc | +69 (the runtime: the call, `execve`'s arrays; `gnu.h` 12) | +764 (`Unix` and `CapUnix`, 739 with their interfaces; `flush_all`, `Sys.sigbus`..., `print_endline` flushed) | C stubs for each function, twice (Plan 9's libc and POSIX): OCaml's own are 3,500 lines of C |
| 2026-10-01 | the expected type, with Unix's files: an exception where one is expected (`exception Quit` and a constructor `Quit`); a `try`'s, a record's, a constructor's type from what they hold (`try Some (Unix.stat p) with ...`); an `if`'s second branch under its first's; a type variable is not what another variable says; in Typing, a record's function field under its type. In ix: 3 annotations, `~cloexec:false` at 3 calls | +19 (Scope +12, Typing +7) | 0 (6 lines changed) | |
| 2026-10-01 | goal 2, step 9: Marshal in the runtime (the module was there, its five primitives stubs): OCaml's format, written and read (a channel, a string, a buffer), what is shared written once, a cycle ended; `Marshal.from_bytes`, `to_bytes` | +413 (the runtime) | +7 (the stdlib) | ocaml-light's extern.c and intern.c are 1,174 lines, for its heap |
| 2026-10-02 | no `Re`: mk's `:R:` rules by ix's own `Regex` (ed's, libregexp's algorithm, as mk's own regexps are), moved to `lib_core/commons/`; the `re` library out of dune-project. No `~temp_dir` (an optional argument of OCaml's stdlib): chidb's scratch file in `$TMPDIR`. The census finds the kernel's generated `Memdata` | 0 | +6 (`Pattern`) | a regexp library for mini-ml (xix's copy of ocaml-re is 3,627 lines) |
| 2026-10-02 | `Lexing` and `Parsing` written again for mini-ml (plan_lex_yacc.md, step 1): OCaml's names and positions, mini-lex's and mini-yacc's engines in OCaml; the runtime's two stubs out. The census: no test directory among a program's (a test's `files.ml` was taken for `Files`); 249 of 249 | -3 (the runtime) | -504 (the stdlib: 292 lines for ocaml-light's 796) | two C engines in the runtime (ocaml-light's: 423 lines) |
| 2026-10-02 | mini-lex (plan_lex_yacc.md, step 2): `generators/lex/`, ocamllex's files read, a DFA in a table, `as` by a second look at the lexeme (`Lexing.captures`); the same tokens as ocamllex's lexers on 607,102 tokens of ix | 0 | +550 (mini-lex, 454 without interfaces), +62 (`Lexing`'s captures; `Char.lowercase_ascii`) | ocamllex is 3,034 lines; a C engine in the runtime |
| 2026-10-02 | mini-yacc (plan_lex_yacc.md, step 3): `generators/yacc/`, ocamlyacc's files read, the LALR(1) automaton, yacc's precedences and defaults; the same automata as ocamlyacc's for ix's three grammars (249, 399, 528 states, each paired), the same trees on ML's and SQL's corpora | 0 | +695 (mini-yacc, 559 without interfaces) | ocamlyacc is 6,583 lines of C; a C engine in the runtime |
| 2026-10-02 | ix built by ix (plan_mkfiles.md, step 1): `mkfiles/`, `lib_core/mkfile`, `assembler/mkfile`, run by mini-mk: the C library, the runtime, the stdlib and mini-asm by mini-cc, mini-ml and mini-ld; that mini-asm's objects are dune's, to the byte. mini-ml: a unit's equal float, int32 and int64 literals are one block, as OCaml's (a marshalled value's sharing) | +7 (Lower) | +128 (the mkfiles) | |
| 2026-10-02 | no `~/goken` in the build (plan_mkfiles.md, step 1b): `lib_core/libc/`, goken's libc's files that mini-ml's runtime links, copied as they are; mini-ar (`linker/tools/`), `mini-ld -a` out | 0 | +9,300 of C and headers copied (to trim); +54 (mini-ar), +42 (the mkfile's lists) | a dependency on another repository |
| 2026-10-02 | plan_mkfiles.md, step 2: mini-ld, mini-ar and mini-cc built by ix's tools, their output dune's. The stdlib as OCaml's when it runs: `List.concat_map` and `init` in the list's order, Printf's formats usable twice (its four printers one function); the runtime's heap 512 MB; mini-cc's `-O` sorted | +3 (the runtime) | +62 (three mkfiles), -39 (Printf), +5 (List, Opti) | |
| 2026-10-02 | plan_mkfiles.md, step 2: mini-chidb, mini-mk, mini-rc, mini-ed built by ix's tools, their differential tests against dune's builds (all but rc's sigint: no signal handlers yet); the runtime: a channel's size, seeks, `input_binary_int` | +50 (the runtime) | +56 (four mkfiles) | |
| 2026-10-02 | plan_mkfiles.md, step 2: signal handlers. The runtime notes a signal (`ml_signal`, `ml_signal_pending`; a read interrupted says so); `Sys.signal` keeps the handlers, `Pervasives.run_signals` runs them where a program waits (a channel's read, asked again; a system call of `Unix`, then `EINTR`; `kill` to oneself). mini-rc's `sigint` as dune's | +106 (the runtime 92, `gnu.h` 14) | +56 (the stdlib: `Pervasives` 31, `Sys` 26, `Unix` 3; check.sh -2) | OCaml's way (a handler run at any allocation: the collector and every primitive made safe for it) |
| 2026-10-02 | plan_mkfiles.md, step 3: mini-lex, mini-yacc and mini-ml built by ix's tools, and the fixed point (`mkfiles/fixpoint.sh`: ix built by ix's own build, the same 262 files). `List.concat_map` without a call for each element, `escaped` with `\r` and `\b`, `ssa/Alloc` in the values' order | +3 (`Alloc`) | +63 (three mkfiles 49; the stdlib 12; `Link` 2) | |
| 2026-10-03 | signal handlers run after every call of `Unix`'s, not only an interrupted one (bugs/ix.md: mini-rc's sigint missed 1 run in 100 on a busy machine) | +2 (the runtime) | +3 (`Unix.check`) | |
| 2026-10-04 | deriving, used: mlpp's `Derive` writes ppx_deriving's show (the same text, boxes and line breaks, by `Format`: dune builds with ppx_deriving itself, and the two builds' dumps are the same bytes, 65,906 lines of mini-ml's own `Scope.ml` by `-dast`). Derived: mini-ml's `-dast`, `-dscope`, `-dir`, mini-cc's `-dir`; a stub `let show_x _ = "NO DERIVING"` before the types for a compiler without deriving (xix's way). mini-mk's two dumps are not derivable (a graph with cycles, tables filtered). `Format`'s boxes without a depth limit, as OCaml 4.14 | +35 (`Derive`: 106 to 141) | -284 (the four printers: 316 lines out, 32 in for the attributes, the stubs, five printers of names by hand) | |
| 2026-10-04 | the stdlib without `Set` and `Map` (ocaml-light's, polymorphic, under OCaml's names: no program named them; ix's set is `commons/Set_`): `lib_core/collections/README.md` | | -506 | functors, still |
| 2026-10-04 | `Format` trimmed to what ix uses (the formatters, the functions on one, `fprintf` and `printf`; not tabulation boxes, the margin's and the limits' setters, the functions on the standard formatter: its `.mli` lists them), and no `Fmt` (`Logging` calls `Format` itself) | | -389 | |
| 2026-10-04 | `Either` and `Result` trimmed to their type and core (no program called their functions; each `.mli` lists what was dropped) | | -247 | |
| 2026-10-04 | the stdlib's values no program names, out, by judgment (what is general stays): `Float` (the hyperbolic functions, `log10`, `acos`, `asin`, the operators as functions, and its commented-out code), `Int` (the operators as functions), `Uchar`, `Bool`, `Sys` (ten signals), `Obj` (the tags), `Gc` (ocaml-light's counters and parameters: the runtime's three stubs with them), no `Lazy` (mini-ml has no lazy); each `.mli` lists them (`scripts/stats/trim_stdlib.py`) | -3 (the runtime) | -475 | |
| 2026-10-04 | mini-cc's lexer by ocamllex and mini-lex (`languages/c/Lexer.mll`), not by hand: the same listings on every C file of ix, test-goken passes | | -14 (220 to 206) | |
| 2026-10-04 | the stdlib, a second pass: `Filename` for Unix and Plan 9 only (ocaml-light's also had Windows's and the old MacOS's names, chosen by `Sys.os_type`: 208 lines to 84), `Buffer.add_substitute` and its three helpers, `List.sort_bool`, `Array.create_matrix`. The rest of what no program names is general (`flatten`, `split`, `merge`, `peek`, `fold_right`...) or used inside its module: kept | | -190 | |
| 2026-10-04 | the stdlib's documentation, shorter (the author: "stdlib doc is fair game for now"): in the 37 interfaces from OCaml, a value's comment cut to its first sentence and the exceptions it raises (`scripts/stats/short_docs.py`); the modules' headers, the license and ix's own comments kept; by hand, what the first sentence lost and matters: `lsr` and `asr`, `floor` and `ceil`, `Printf`'s conversions as a short list of what this Printf has (`%S`, `%C`, `%h` too). m-ix 72,616 to 72,022. **An experiment**: the author thought the documentation fair to have ("fair game" was misread), so it may be restored (`git show 97d0d88`); the modules' headers are not to be cut | | -594 (comments) | |
| 2026-10-04 | three more types said once, each in a file of types without a `.mli`: `Host_calls` (the host's record of calls, shared by `Linux`, `Plan9` and `Host`), the linker's `Program` (symbols, instructions, data; `Link` keeps the passes), `Bytecode` (the database machine's instructions and values). `Typing.show` stays: its type is private to `Typing` | | NNN | |
| 2026-10-04 | the C library's formatter and arm's vlongs, ix's own (`lib_core/libc/ix/`, marked as not goken's: its README, the files' headers, authors.txt): `ix/fmt.c` (603 lines: `snprint`, `sprint`, `strtod`, `NaN`..., floats exact both ways by one multiplication on large numbers) for goken's `fmt/` and what only it needed (`utf/`, `ctype`, `assert`, `errno`, `strerror`: 2,874 lines); `ix/vlrt.c` (337) for `port/vlrt.c` (760), the same functions. Checked against glibc and gcc on the host (`libc/tests/check.sh`: 0 differences) and by `modern/float_formats.ml` on arm and arm64. Fixed on the way: `-0.` read back, the smallest vlong to a double (bugs/goken.md 32, 33), `%f` of 1e308 cut at 128 bytes. m-ix 71,949 to 69,256 | | -2,693 | |
| 2026-10-04 | `Arg` for the command lines whose options are their own (mini-asm, mini-lex, mini-yacc, mini-ml), not the twins' (mk's, rc's, chidb's getopt, 5l's `-H7`: the original's conventions, which `Arg` does not read): an unknown option is an error with the list of options, `-m 9` too; `-h` still the examples. `Arg` (382 lines of the stdlib) had one user, tiny-build | 0 | 0 (60 lines for 60) | |
| 2026-10-04 | the two compilers' stack machines as types, `Ir` (`languages/ml/simple/Ir.ml`, `languages/c/simple/Ir.ml`, no `.mli`): `Ir.t` for `Lower.ir`, `Ir.show` for `Lower.show_ir`; `Lower` keeps its `.mli`, now the functions only (`unit_`, `func`...). `-dir` prints `(Ir.Call ...)`. m-ix 69,256 to 69,199 | | -57 | |
| 2026-10-04 | the SSA form as types, `Ssa.ml` (no `.mli`); what builds, checks and prints it `Ssa_build` (with its `.mli`). In `ssa/`, counted apart from m-ix: 37 lines of types said once. The survey of what is left (types concrete in both a `.mli` and its `.ml`, outside the stdlib): 492 lines in 91 modules, most 1 to 7 lines each: stopped there | | 0 (ssa/: -30) | |
| 2026-10-04 | the CPUs' states in `Arm64_isa` and `Arm32_isa` (an architecture: its instructions and the state they act on), said once. And a pilot of an extension of OCaml by mlpp, `type t = [%mli]` (the `.mli`'s definition; `= _` its first spelling): `Mmu32` and `Mmu64`, dune's `ix_machine` preprocessed by the workspace's mini-ml. merlin types the fields (no error; locate stops at the hole), ocamlformat and semgrep's parser read it, plain ocamlc says "Uninterpreted extension 'mli'". Not done: a `builder/Types.ml` gathering four modules' types (the author: against good programming; a `Graph.t` rather than a `Types.t`) | +3 | -86 (the states -60, the pilot -26; dune +3) | |
| 2026-10-04 | `type t = [%mli]` the only spelling (`= _` out of the parser and of mlpp's detection), and applied to mini-mk: `Pattern.meta`, `Mkfile`'s `attrs`, `rule` and `io`, `Graph`'s `node` and `arc`, `Recipe.job`, `Build`'s `flags` and `io`, `Outofdate.hashes`: each type stays in its module, said once in its `.mli`; dune's `ix_mk` preprocessed by the workspace's mini-ml. One-line types are left as they are (a hole is a line too). m-ix 69,111 to 69,038 | -4 | -68 (dune +3) | |
| 2026-10-04 | `[%bits]` used at last (decision 2, phase 4): `machine/Arm32.ml`'s decoder, one clause an encoding as the manual draws it, in the order it had; `decode_check.py`: 2,311 words, 0 differ; mini-5i as fast (a program of 3 s: no difference measured). The VFP's two helpers are left with `field` and `bit` (a register's number is in two places) | 0 | -13 (105 lines to 92; lines with `field w` or `bit w`: 82 to 21) | |
| 2026-10-04 | `machine/Arm64.ml`'s decoder by `[%bits]`, group by group (immediates, branches, the system's, loads and stores, registers, floating point, movi): `decode_check.py -64`: 2,218 words, 0 differ; mini-5i as fast (an arm64 program of 4 s, three runs each: no difference). Lines with `field w` or `bit w`: 123 to 4. Not read by mlpp: an or-pattern of two `[%bits]` (three clauses instead). m-ix 69,025 to 68,978 | 0 | -47 | |
| 2026-10-04 | the rest of `machine/Arm32.ml`'s decoder by `[%bits]`: the shifter's operand and the VFP's two functions (a register's number: its 4 bits and its extra one, two fields); `decode_check.py` and `random_blocks.py -vfp`: 0 differ. The linker's encoders are left: words of 32 bits as `int32` with `lsl` and `lor` redefined, built a part at a time as 5l does (`oprrr m sc lor (rt lsl 12) ...`), where `[%bits]` writes a whole word of `int`. m-ix 68,978 to 68,964 | 0 | -14 | |
| 2026-10-04 | mlpp: a list comprehension, `[%list e \|\| x <- xs; y <- ys; c]` (its section below), to show the mechanism more than to save lines: `tests/pp/comprehension.ml` by OCaml and by mini-ml, an error's place (`errors/generator.ml`); used in `builder/CLI.ml` | +45 | 0 | |
| 2026-10-05 | a file's header in two lines (the author; the copyright and `license.txt`) for the nine it had, in 467 files (`scripts/stats/short_header.py`). m-ix 68,999 to 67,146 | | -1,853 | |
| 2026-10-05 | mini-ml reads `let*` (binding operators, desugared by the parser: ocaml-light's `letstar.ml` passes, out of the corpus's exceptions); `Common.( let* )` is `Option.bind`. mlpp's `a \|! b`, an option's value or else `b`, lazy (its section below): 20 places, most in mini-git, whose dune library mlpp now reads | +21 | -2 | |
| 2026-10-05 | `I64` (`lib_core/commons`): Int64's arithmetic as operators in a local open, `I64.((v lsr 32) land m)`, in OCaml and mini-ml alike (not in `Int64`, whose interface is OCaml's). `machine/Arm64.ml` (89 expressions), `Mmu64`, `raspberry/Pi4.ml`, by `scripts/stats/to_i64.py`; `random_blocks.py -64` and `-64fp`: 0 differ. m-ix 67,146 to 67,208 | | +41 (the module) | |
| 2026-10-05 | a Plan 9 target, on arm (plan_rio.md, stage 1): `mini-mk O=5 OS=plan9` (under `_mk/5-plan9`, linked `-H2`); `lib_core/libc`'s Plan 9 files, goken's as they are (15 files, 1,272 lines); the runtime's `-Dplan9`: the libc's own calls where Linux's were by number (a channel's read, `chdir`, `exec`, the break for Marshal's memory), `Sys.command` by rc and `await`'s line, `exit n` the status "n", a heap of 64 MB a half; `_syscall6` for Plan 9's calls by number (`libc/ix/`, 27 lines). 18 of tests/modern's 24 programs pass as Plan 9's under mini-5i (`OS=plan9 run.sh 5`); hello on mini-9pi (`kernels/9pi`: `make check-ix`) | +95 (the runtime) | +1,299 of C and assembly (the libc: 1,272 copied, 27 new), +9 (mini-5i: the VFP on for a Plan 9 program, a number's status), +35 (mkfiles, hello) | goken's `wait`, `tokenize` and the runes' files for `Sys.command` (550 lines) |
| 2026-10-05 | `Unix` on Plan 9 (plan_rio.md, stage 2): `lib_core/system/plan9/Unix.ml`, with an interface of its own (the part a shell and an editor ask: files, pipes, processes, the environment, `lseek`), each function a system call of Plan 9's by its number; a descriptor's close-on-exec kept there (Plan 9's is the open file's), `/env` read and written as an environment, `await`'s line as a `process_status`, the kernel's words as an errno and as `error_message`. The runtime: notes (`notify`: interrupt, hangup, alarm noted as signals; a read they interrupt). mini-rc and mini-ed build for Plan 9 unchanged, and run on mini-9pi (`make check-ix`) | +35 (the runtime) | +393 (`Unix`: 300, its interface 93), +30 (mkfiles, the tests) | a port of mini-rc to Plan 9's own calls |
| 2026-10-05 | plan_rio.md, stage 2's end: `Sys.os_type` "Plan9" on Plan 9 and "Unix" on Linux (it was "Plan9" on both); `Sys_plan9` (a child's last words; nothing off Plan 9), used by mini-rc for `$status`; `Sys.time` by `/dev/cputime`; mini-mkbootdir (`kernels/tools/`) in the place of a Python script | +24 (the runtime) | +45 (mini-mkbootdir), +25 (`Sys_plan9`, its three files), +8 (`Unix`), +5 (mini-rc) | |
| 2026-10-05 | plan_rio.md, the bootdir ix's own: `utilities/` (mini-ls, mini-cat, mini-echo, mini-bind, mini-mount: Plan 9's, as principia's, 51 cases under mini-5i), `Sys_plan9` (`exits`, `bind`, `mount`, a directory's entries), xix's `Exception`, `Exit`, `Fpath_`, `Chan`, `Cmd`, `FS` in `lib_core/commons/` (mini-ml reads them as they are), Plan 9's `Unix.time` and `gmtime`, Plan 9's rcmain in mini-rc; `kernels/9pi`'s `make ix` and `mini-pi mini-9pi` | 0 | +321 (the five utilities), +536 (xix's six modules with their interfaces, copied), +159 (`Sys_plan9`, its three files), +45 (`Unix`), +40 (mini-rc's rcmain) | |
| 2026-10-05 | plan_rio.md, stage 3: mini-mkcard (`kernels/tools/`): an SD card's image, an MBR, a FAT16 with the Pi1's firmware and mini-9pi's image, a second partition; read by the host's tools and by principia's fdisk and dossrv on mini-9pi (`make check-card`) | 0 | +158 (mini-mkcard) | mtools, mkfs.vfat and sfdisk in the build |
| 2026-10-05 | threads (plan_rio.md, stage 4): the runtime's `thread_new`, `thread_switch`, `thread_free` over the value stacks it had for the kernels; `ml_swtch` in the start object (9 instructions an architecture); `lib_core/concurrency/`: `Thread` (the scheduler, in OCaml), xix's `Mutex`, `Condition`, `Event` (ocaml-light's, as they are), `Source` (a descriptor's reads and a timer as a channel's messages: a process a source, one pipe). The same programs with OCaml 4.14's threads: `tests/modern/threads.ml`, `lib_core/commons/tests/sources.sh`; on arm64, arm, Plan 9 under mini-5i, and on mini-9pi | +83 (the runtime), +11 (Gen) | +127 (`Thread`), +437 (xix's three, copied), +133 (`Source`, its two files and interface) | OCaml's systhreads (a master lock, the collector and every primitive made safe for threads), or ocaml-light's bytecode threads and their `select` |
| 2026-10-05 | plan_rio.md, stage 5: `lib_networking/9p/` (9P2000's messages, their bytes both ways, a server's loop), `kernels/9pi/filesystems/user/dossrv/` (mini-dossrv: FAT12, 16, 32 and long names, read); the card's FAT mounted on mini-9pi by ix's own programs; the same 284 lines as principia's dossrv on principia's card, but the names' case | 0 | +435 (`lib_networking/9p`, with its interfaces), +249 (mini-dossrv's directory: `Fat` 174, mini-dossrv 75) | principia's dossrv is 4,192 lines of C (it writes too) |
| 2026-10-05 | plan_rio.md: mini-fdisk (`kernels/9pi/devices/storage/user/fdisk/`: fdisk's `-p`, the MBR's partitions as lines for the disk's ctl); mini-9pi's `conf/boot.rc` mounts the card's FAT (mini-fdisk, mini-dossrv, mini-mount) | 0 | +70 (mini-fdisk) | principia's fdisk is 1,125 lines of C (an editor of partitions) |
| 2026-10-05 | plan_rio.md, stage 7a: `lib_graphics/`, the client's side of the draw device, written anew (`Point`, `Rectangle`, `Display`, `Draw`, `Font`; Plan 9's default font as data); hellodraw on mini-9pi's screen (`make check-draw`); the kernel's C library has a square root (a thick line panicked) | 0 | +300 (`lib_graphics`, with its interfaces), +194 (the font's data), +20 (hellodraw), +12 (the kernel's `sqrt`) | xix's `lib_graphics/draw` is 1,386 lines without its font |
| 2026-10-05 | plan_rio.md, stage 7b: `lib_graphics`'s `Mouse` and `Keyboard` (each a `Source`), `Menu` (Plan 9's menuhit); hellomenu on mini-9pi with QEMU's USB keyboard and mouse (`make check-menu`: 8 screens, the same under mini-qemu and QEMU); `make ix-usb` (principia's usbd, until ix has its own) | 0 | +119 (`Mouse`, `Keyboard`, `Menu`, with their interfaces), +45 (hellomenu) | |
| 2026-10-05 | plan_rio.md, stage 7c: `windows/`, a first mini-rio, written anew (`Terminal`, `Window`, `Fileserver`, `Rio`: one loop over the mouse, the keyboard and the windows' 9P requests); a window swept out with mini-rc in it, on mini-9pi (`make check-rio`: the C rio's check's steps, 11 screens, the same under mini-qemu and QEMU). `P9_server`'s `make`, `request` and `Later`; `Sys_plan9.rfork`; `Display`'s desktops and windows (the kernel's layers) | 0 | +328 (`windows/`), +60 (`lib_networking/9p`, `Sys_plan9`, `Display`) | principia's rio is 8,170 lines of C, xix's orio 1,762 of code |
| 2026-10-05 | `Binary` (`lib_core/commons`, plan_ml_features.md): a format's numbers read in a string, added to a buffer, set in bytes, 32 bits by halves (arm's int); for the helpers of `lib_networking/9p/P9_wire`, mini-dossrv's `Fat`, mini-fdisk, mini-mkcard, mini-git's `Pack`. The card's image the same bytes, `objects.sh` passes | 0 | +31 (`Binary` 48, 28 of them its interface; the five files -17) | |
| 2026-10-05 | `Binary`, the linker's: a header as a list of fields in either order (`Binary.le`, `Binary.be`; `Exe`'s own `fields`, which had the low byte first only: Plan 9's a.out header a list too), a number's bytes by its width (`Binary.set_le`: `Link`'s data, three loops). `golden.sh`: the 64 executables' bytes the same | 0 | +19 (`Binary` +30, 11 of them its interface; `Exe` -11) | |
| 2026-10-05 | plan_rio.md: a program that draws in a window of mini-rio's (a window's `winname`, `mouse`, raw keys; `Display.name`, `named`, `screen`; hellorio); New's cross and the rectangle shown while swept, Delete's sight (`Cursor`, `Cursors`); `make check-rio` with 13 screens; `mini-pi -g mini-9pi` | 0 | +128 (`windows/`), +36 (hellorio), +22 (`Cursor`), +30 (`Display`, `P9_server`) | |
| 2026-10-05 | plan_rio.md: mini-rio around a thread a window (Rob Pike's design: `Window.run`, a loop on the window's channel; the file server a thread; the window system's keeps the mouse, the keyboard and the menu); 256 threads at once (they were 64), `Thread.create` past them raises Failure (`tests/plan9/thread_limit.ml`) | +2 (the runtime) | +20 (`windows/`: 476 lines for 456), +17 (the test) | |
| 2026-10-05 | plan_rio.md: `apps/misc/`, mini-colors (Plan 9's colors: its 256 colours, a square pointed at said); on mini-9pi's bare screen and in a window of mini-rio's (`make check-colors`: 16 screens) | 0 | +71 (mini-colors) | principia's colors.c is 199 lines |
| 2026-10-05 | mlpp's type classes (their section below): `[@@class]`, `[@@instance]`, `[%using: 'a show]`; the dictionaries found by Typing and written by a second rewrite (`Pp.classes`); `-pp` lenient, its errors OCaml's (`[%ocaml.error]`); `-L lib_core`; a type variable's name one type in its definition. `lib_core/commons/Prelude` (show, eq, ord; dune's `ix_prelude`). `pp.sh`: 3 programs and 4 errors more, by OCaml and by mini-ml; merlin checked | +520 (Typing 135, Pp 156, Resolve 77, CLI 72, Derive 23, the parser and the trees 19, the `.mli`s 38) | +214 (Prelude) | |
| 2026-10-05 | plan_rio.md: mini-rio's Move, Resize, Hide (rio's menu; `Display.origin`, `Terminal.reshape`; messages to the window's thread), Delete typed in a window an interrupt for its processes; `make check-rio`: 28 screens | 0 | +103 (`windows/`: 565 lines), +14 (`Display`) | |
| 2026-10-05 | plan_rio.md: a program that draws in a window is told when it is moved or made another size (the mouse file's `r`, `Mouse.state`'s `resized`, `Display.screen` asked again); hellorio and mini-colors draw again; `make check-colors`: 26 screens | 0 | +25 (`Mouse`, `Display`, `Window`, the two programs) | |
| 2026-10-05 | plan_rio.md: scrolling back in a window of mini-rio's (`Terminal`: 1,000 lines kept, the arrows, a scroll bar); `Keyboard.receive` gives whole characters (a read may end inside one); `make check-rio`: 33 screens | 0 | +45 (`Terminal`), +20 (`Keyboard`), +5 (`Window`, `Rio`) | |
| 2026-10-02 | plan_mkfiles.md, step 3, the other programs: mini-5i, mini-git, mini-diff, mini-merge3 and the 13 tiny programs built by ix's tools (five of the tiny ones do not pass their tests yet); `Sys.chdir`, `Sys.time` in the runtime | +16 (the runtime) | +116 (three mkfiles; the tests take their program from the environment) | |
| 2026-10-01 | not for mini-ml, but fewer lines for it to compile: tiny's real architecture arm64 only, tiny-arm without its assembler (plan_tiny_arm64.md) | | -375 | |
| 2026-10-06 | plan_rio.md: mini-rio's scroll bar takes the three buttons (rio's: back, forward, to a place), by the mouse sent to the window and `Terminal.pressed` (no message of the bar's own); the graphical checks as short sessions side by side (`make check-windows`: 112 seconds) | 0 | +30 (`Terminal`, `Window`, `Rio`) | |
| 2026-10-06 | plan_rio.md: text selected in a window of mini-rio's (the left button), the middle button's menu: snarf, paste, send; all in `Terminal` (`mouse`, `menu`), as rio's terminal.c: `Window` one field more and no message | 0 | +108 (`Terminal` +80, `Rio`, `Window`) | |
| 2026-10-06 | plan_rio.md: characters that are not ASCII's in mini-rio's windows (UTF-8): `Utf8` (lib_core/commons: the stdlib's decoding and encoding under `decode` and `add`, and a string by its characters), used by `Font`, `Keyboard`, `Terminal`, `Window`, and by mini-ed, `Regex`, `Json` and `Diff` in place of their own loops | 0 | +49 (`Utf8` +62, its users -13) | |
| 2026-10-06 | plan_rio.md: mini-rio's `/dev/snarf` (the text kept by the windows' menu, read and written by the programs: `Fileserver`, `Terminal.snarf`) | 0 | +16 | |
| 2026-10-06 | plan_rio.md: mini-9pi's compose key (Alt and two or three keys: é typed): `Latin1` (principia's latin1.c and its table of 100 rows), `Kbd` waits for the sequence | 0 | +170 (`Latin1` 165, 100 of them the table) | |
| 2026-10-06 | plan_ml_features.md, 2: mini-yacc reads menhir's standard rules (`list(x)`, `option(x)`, `boption`, `loption`, `nonempty_list`, `separated_list`, `separated_nonempty_list`), each use made rules by the reader (`Lalr` and `Parsing` as they were); a parser has menhir's `exception Error`. The database's grammar in them, by menhir under dune and by mini-yacc in the mkfile; ML's stays ocamlyacc's (its positions are `Parsing`'s, which menhir doesn't keep) | 0 (mini-yacc +36) | -39 (`database/Parser.mly` -40, `Sql` +1) | |
| 2026-10-06 | plan_ml_features.md, 2: mini-yacc reads menhir's `x?`, `x*`, `x+` (`option(x)`, `list(x)`, `nonempty_list(x)`: the same expansion); the database's grammar with them (`sql_query+`, `OUTER?`, `where_condition?`) | 0 (mini-yacc +4) | 0 | |
| 2026-10-06 | plan_rio.md: mini-usbd, ix's own USB keyboard and mouse driver, a program (kernels/9pi/buses/user/usbd: `Usbdev`, `Hid`, `Usbd`), in place of principia's usbd (4,400 lines of C with its library and kb): hubs, HID's boot protocol, the keys' repeat by the keyboard's idle reports | 0 | +417 | |
| 2026-10-06 | plan_ml_features.md, 2: ML's grammar by menhir under dune (mini-yacc in the mkfile): its positions menhir's `$sloc` and `$loc($n)`, passed by each action to the header's helpers (105 actions; `Parsing`'s functions, which menhir doesn't keep, out); mini-yacc reads the two (`Output`); `CLI` catches menhir's `Parser.Error` too. The trees the same as ocamlyacc's parser's, on 800 files | +6 (`Parser.mly` +4, `CLI` +1, dune) (mini-yacc +10) | 0 | |
| 2026-10-06 | plan_ml_features.md, 2: ML's grammar's lists and optional parts by menhir's standard rules (`x*`, `x+`, `x?`, `boption`, `separated_list`, `separated_nonempty_list`): 13 rules gone or a line, their uses' `List.rev` too; a list that may end with its separator, one a precedence decides and `type t = \| A` stay rules (the grammar's header) | -36 (`Parser.mly`: -46, and 10 of comment) | 0 | |
| 2026-10-06 | plan_rio.md: USB devices unplugged and plugged again (`make check-plug`, QEMU's device_del and device_add); the kernel's `usb_transfer` disables a channel left enabled (a bug: bugs/ix.md) | 0 | +8 (C, `kernels/lib_machine/usb.c`) | |
| 2026-10-06 | plan_ml_features.md, 2: mini-yacc warns of what a grammar says for nothing (a precedence and a `%prec` that decide no conflict, a token in no rule, a non-terminal no start symbol leads to: `Lalr`; `menhir --lalr`'s, the same); ML's grammar without its 5 levels and 19 `%prec` of no use (the same automaton) | -5 (`Parser.mly`) (mini-yacc +20) | 0 | |
| 2026-10-06 | plan_tiny_gaps.md: tiny-shell's two left: a line ended by `\|`, `&&` or `\|\|` continued (the text's end there an error), a signal's status rc's (`signal: interrupt`, said on the standard error) | 0 | +14 (`TinyShell.ml`) | |
| 2026-10-06 | plan_rio.md: the kernel as its own usbd (`echo kernel > '#u/usb/ctl'`: `Kusb`, 88 lines), with mini-usbd's code: kernels/9pi/buses/lib_usb (`Usbdesc`, `Hid`, `Usbbus`: 352), mini-usbd 165 where it was 417; the kernel's `Chan` is `Kchan` | 0 | +188 (605 for 417), +30 in `Devusb`, `Usbdwc`, `Devmouse` | |
| 2026-10-06 | plan_rio.md: a FAT by the kernel itself (`Kdos`: `bind '#Fdos' /root`, 94 lines), with mini-dossrv's code: kernels/9pi/filesystems/lib_fat (`Fat`, moved, given how its device is read) | 0 | +108 (`Kdos` 94, `Fat` and `Dossrv` +14) | |
| 2026-10-06 | plan_rio.md: the kernel's pixels split as its USB and its FAT: kernels/9pi/lib_graphics/lib_memdraw and lib_memlayer (the `Mem*` modules, with no name of the kernel's left: `Memimage.to_screen`), `Kdraw` the kernel's part (was `Draw`) | 0 | +8 (947 moved) | |
| 2026-10-06 | plan_rio.md (not committed): FAT written (`Fat`: files written, emptied, made with long names, removed; a host test against mtools and fsck.vfat), in mini-dossrv and `Kdos`; `Kproc`, the kernel's first own process, for `Kusb`'s look at the ports; boot.rc's fall back to `Kdos`; `make check-all` | 0 | +545 (`Fat` +350, `Kdos` +33, `Dossrv` +24, `Kproc` 35, `Kusb` +9, tests 95) | |
| 2026-10-06 | plan_rio.md (not committed): xv6's file system on the card's second partition: kernels/9pi/filesystems/lib_xv6fs (`Xv6fs`, with a second block of numbers for files past 314 KB), `Kfs` the kernel's device (`#x`), mini-mkfs (kernels/tools), a host test | 0 | +555 (`Xv6fs` 278, `Kfs` 104, mini-mkfs 54, tests 120) | |
| 2026-10-06 | plan_rio.md: mini-xv6's `Fs` has ix's extension to xv6's format (files past 314 KB: a second block of numbers), marked as such there and in `Xv6fs`; `make check-large` in kernels/xv6 | 0 | +33 (`Fs`) | |
| 2026-10-06 | plan_rio.md: mini-rio, hellorio and mini-colors on the card's xv6 partition (boot.rc binds its bin after /bin), out of the kernel's image (10.2 MB for 12.4); the graphical sessions with the card | 0 | 0 (the Makefile, boot.rc) | |
| 2026-10-06 | plan_rio.md: the card's xv6 partition is mini-9pi's root (boot.rc: /root, / after the kernel's, bin/arm on /bin, the shell in /usr/pad), the FAT at /mnt/fat; mini-mkfs makes empty directories; a read left waiting by a program that ended no longer takes the next line typed (`P9_server`, `Window`) | 0 | +25 (`P9_server` +14, `Window` +5, mini-mkfs +6) | |
| 2026-10-07 | plan_rio.md: utilities/'s mini-pwd, mini-mkdir, mini-rm and mini-cp (Plan 9's, as principia's: 187 lines for its 440 of C; 98 cases under mini-5i with the five before), on the card's xv6 partition; `FS`'s `open_out_fd`, `mkdir`, `remove_any`, `getcwd`; Plan 9's `Unix.mkdir`, `unlink`, `rmdir`, `getcwd`; a directory made by the kernel's `Kfs` and `Kdos` (a bug: bugs/ix.md) | 0 | +187 (the four utilities), +24 (`FS`), +23 (`Unix`), +2 (`Kfs`, `Kdos`) | |
| 2026-10-07 | plan_rio.md: utilities/'s mini-mv, mini-touch and mini-chmod (230 lines for principia's 455 of C; 147 cases under mini-5i in all), on the card; `Sys_plan9`'s `rename`, `chmod`, `set_mtime` (a wstat each), `FS.create_fd`; `Fat`'s `rename`, `set_mtime`, `set_read_only`; `Xv6fs`'s `rename` and a file's time written (ix's second extension to xv6's format: the inode's byte 12); `Kfs`'s, `Kdos`'s and mini-dossrv's wstat | 0 | +230 (the three utilities), +34 (`Sys_plan9`), +6 (`FS`), +46 (`Fat`), +28 (`Xv6fs`), +22 (`Kfs`), +18 (`Kdos`), +11 (mini-dossrv) | |
| 2026-10-07 | plan_rio.md: mini-9pi's clock (a write to /dev/time sets it, ix's boot.rc does; /dev/time and /dev/bintime say it); utilities/'s mini-date, mini-mtime, mini-wc, mini-basename, mini-tee and mini-cmp (267 lines for principia's 524 of C; 202 cases under mini-5i in all), on the card; `FS.open_append_fd` | 0 | +267 (the six utilities), +36 (`Devcons`, `Dev`: the clock), +3 (`FS`), +38 (`Kfs`'s cache of the card's bytes: notes_performance.md, 3) | |
| 2026-10-07 | plan_rio.md: utilities/'s mini-sleep, mini-unmount, mini-seq, mini-cleanname and mini-du (216 lines for principia's 544 of C; 253 cases in all), on the card; `FS.cleanname` (mv's, shared), `Sys_plan9.unmount`; the card's session of ix's programs as five short ones at once (check-card 68 s) | 0 | +216 (the five utilities), +7 (`Sys_plan9`), 0 (`FS.cleanname`: moved from mini-mv) | |
| 2026-10-07 | plan_rio.md: utilities/'s mini-grep (on `Regex`: no engine of its own), mini-tail and mini-xd (345 lines for principia's 2,151 of C, 1,335 of them grep's; 321 cases in all), on the card; tests/text_files.sh (no control byte in a source), in test-lite | 0 | +345 (the three utilities) | grep's own automaton: `Regex` is there |
| 2026-10-07 | plan_rio.md: utilities/'s mini-uniq, mini-tr, mini-sed and mini-sort (944 lines for principia's 3,723 of C), mini-ps and mini-time and Plan 9's kill script (129 lines for 301); 481 cases in all; `Sys_plan9.last_times`; mini-5i takes its options before the program's name only; mini-9pi's owner said by boot.rc, /boot and the card's rc/bin in /bin | 0 | +944 (the four text utilities), +129 (ps, time, kill), +9 (`Unix`, `Sys_plan9`: a child's times), +5 (mini-5i) | sed's and grep's own regexps: `Regex` |
| 2026-10-07 | plan_rio.md: utilities/'s mini-test and mini-xargs (177 lines for principia's 551 of C; 549 cases in all), on the card with a session of rc's if and for | 0 | +177 (the two utilities) | |
| 2026-10-07 | plan_playground.md, stage 1: the author's playground's library, its software rasterizer and its Tetris copied (`lib_playground/`, `lib_graphics/software/`, `games/`; `games/survey.sh` says each file's lines gained and lost), changed where mini-ml asks: 9 optional arguments said, a `Bigarray` a `Bytes`, a `Lazy` a `ref`, an `include` written out, `private`, a GADT and a module in a file left out, `Arg.Tuple` done without, a unary plus and a `let rec (f : t) =` respelt. lib_core: `Float.pi`, `hypot`, `rem`, `Result.map` (OCaml's); libc's `cos(0)` is 1 (bugs/goken.md, 35) | 0 | +5,429 (3,140 of .ml), +10 (lib_core), +7 (libc) | optional arguments, Bigarray, Lazy, include, private types, GADTs |
| 2026-10-07 | plan_playground.md, stage 2: Tetris on mini-9pi (`lib_playground/platforms/software/`, `Session`, `Redraw`: what changed only is drawn; 51 to 52 frames a second under QEMU, 0.3 at first). `Unix.gettimeofday` for Plan 9, `Keyboard.left` and `right`; the kernel: its clock by the timer's count, a process's floats kept through an interrupt, `Memdraw`'s path from 32 bits to 16. `Lehmer`'s state a float (a Pi1's int has 31 bits) | 0 | +485 (the platform, Session, Redraw), about +60 (the kernel) | |
| 2026-10-07 | mini-hoc (`utilities/calc/hoc/`): principia's hoc, its lexer in ocamllex and its grammar in menhir's yacc (mini-lex and mini-yacc in the mkfile), trees run as they are where the C compiles to a stack machine; 731 lines with comments for the C's 1,476; 65 recorded cases and a fuzzer against goken's hoc. `Lexing.engine` reads nothing past a token that cannot grow; the runtime's `tanh` past 21 | +1 (runtime.c) | +731 (mini-hoc), +5 (`Lexing`) | |
| 2026-10-07 | mini-awk (`utilities/text/awk/`): principia's awk (9front's), its lexer in ocamllex and its grammar awkgram.y's rule for rule in menhir's yacc (mini-lex and mini-yacc in the mkfile; the same 40 and 81 conflicts left to both), cells and tables as tran.c's, a tree run where the C has a table of functions; 2,425 lines with comments for the C's 5,679; 74 recorded cases and a fuzzer against principia's awk built by goken (`tests/reference.sh`). mini-ml: a format's `*` typed | +5 (`Typing.format`) | +2,425 (mini-awk) | |
| 2026-10-07 | mini-dc and mini-bc (`utilities/calc/dc/`, `utilities/calc/bc/`): principia's dc.c (numbers of any size in base 100, its bytes kept where its answers are about them: `Num`, `Dc`) and bc.y (its lexer in ocamllex, its grammar in menhir's yacc, no conflict; Plan 9's if, while and for, which principia's has broken), bc's programs run on dc's machine in the same program, bclib in it; 13 and 11 recorded cases, a fuzzer for dc, against principia's dc built by goken's 7c and 9base's `bc -c`. On mini-9pi's card with mini-hoc and mini-awk. mini-ml's `int_of_string` takes a `+`; `Regex`'s messages name the operator | +2 (runtime.c) | +895 (mini-dc), +431 (mini-bc, and bclib, 251) | |
| 2026-10-07 | Marshal in ML (plan_ml_features.md, 3): `lib_core/core/Marshal.ml`, 372 lines for the runtime's 444 of C; a table of the blocks written by their address, computed anew after a collection (`gc_collections`); `Obj.new_block` named again; no `output_value` and `input_value` in Pervasives; 12% more CPU for ix built by ix. mini-ld's `Follow` on arm: a `B` to a TEXT not followed | -441 (the runtime: -444, +3) | +311 (the stdlib) | |
| 2026-10-08 | mini-ml's code in place (plan_playground_speed.md, the toolchain plan's A and B, M4a): a block taken from the heap by the code (`Gen.alloc_in_place`), a float's arithmetic, negation and comparison the processor's (`Lower.floats_in_place`: `Ir.Float2`, `Float1`, `FloatOfInt`, `IntOfFloat`), an unknown function called with all its arguments when its closure says it takes them (`Lower.calls_whole`; the curry functions in the start object), a string's unchecked byte and its length (`strings_in_place`); `mini-ml -calls` turns them off. `sched` 4.63 times ocamlopt's to 2.81, `maps` 1.26 to 0.80; `tests/costs.sh`, `tests/modern/floats_in_place.ml`. The runtime: `ml_hp` and `ml_limit` not static, `Gc.get` and `Gc.set` (OCaml's `space_overhead`: +30 of C, +12 in `lib_core/core/Gc`), `blit_string` and `fill_string` a word at a time (+45) | +272 | +244 (`Display`'s own bytes, the draw platform's short ways, `Source.alarm`, the loop's meter, `Gc`, `Bytes.length` the primitive) and +493 in the kernels (`Memdraw`, `Memshape`, `mem_rows`, the Pi1's caches) | |
| 2026-10-08 | plan_rio.md: a window's border as a handle in mini-rio (rio's: the cursor of the corner or side under the mouse, the left or middle button pulls it, the right one moves the window): `Cursors` (rio's box and eight corners, their bits), `Rio` (`border`, `hover`, `grab`; `band`, the one loop under the sweep, Move and the border), `Window.on_border` | 0 | +88 (54 of them the cursors' bits) | |
| 2026-10-08 | plan_scheme.md and plan_pascal.md, stage 1: the playground's Scheme (`languages/scheme/`, mini-scheme) and Pascal (`languages/pascal/`, mini-pascal, with `lib_terminal/`'s `Line_discipline`, `Vt`, `Talk`), copied and made what mini-ml takes: 9 optional arguments said, 2 `Map.Make` one `Scheme_map` (47 lines), a `let open`, a polymorphic recursion (`Talk.run`), a constructor chosen by its type (`Result.Error`); lib_core's `Float.is_integer`, `Array.for_all2`, `String.fold_left` | 0 | +5,824 (316 ix's own: the two commands, `Scheme_map`; 17 in lib_core) | functors, optional arguments, polymorphic recursion, constructors by type |
| 2026-10-08 | plan_kernel_ocaml4.md, step 7: the kernels' strings that are written are `Bytes` (14 files of `lib_machine` and mini-9pi; OCaml 4.14 the checker, its `String` shim deleted), `Bytes.get` and `Bytes.set` the primitives in lib_core as `s.[i]` was. mini-ml itself not changed: its `Bytes.t` is `string` still (a `bytes` of its own is the plan's "Left") | 0 | +5 (`lib_core/base/Bytes.ml`); the kernels +1, and -18 (the shim) | none |
| 2026-10-08 | plan_kernel_ocaml4.md, step 8: `bytes` a type of mini-ml's own (`Resolve.bytes_d`; `s.[i] <- c` is `Bytes.set`), a string not written. lib_core's stdlib made so, 16 files: `Bytes` its own primitives and `unsafe_to_string` the identity, `String` without `set`, `create`, `fill`, its strings made as bytes and given whole, the channels', `Unix`'s, `Buffer`'s and `Marshal`'s buffers bytes. ix's programs and kernels as they were (OCaml 4.14 had checked them). `tests/modern/byte_strings.ml`, `tests/refused/` | +3 | +10 in lib_core (182 added, 172 removed); and `Bytes.mli`, OCaml 4.14's with its text, 452 lines (44 declarations) | none: a check more |
| 2026-10-08 | plan_scheme.md and plan_pascal.md, stage 2: `scheme` and `pascal` on mini-9pi's card, at its console (`check-scheme`, `check-pascal`): the two commands flush before a line is waited for and before an error (`Console.print` does not), a file not there said so on Plan 9 | 0 | +11 (the two `CLI`; and `queens.scm`, 31 lines of Scheme) | none |
| 2026-10-08 | plan_scheme.md's stage 3 and plan_gui.md: TinyDrScheme, the playground's gui (`lib_gui/`, `Gui`, `Bigbang`) and the 7GUIs (`examples/`, with `gui4`, `Formula`, `Undo`, `Sheet`, `Sheet_view`), copied and made what mini-ml takes: 27 optional arguments said, the polymorphic variants of a menu's answer and of five programs' messages made types, a third `Map.Make` (`Scheme_map` moved to lib_core as `Map_`, +24 for `remove`) | 0 | +8,527 (242 gained and 169 lost against the playground's) | optional arguments, polymorphic variants, functors |
| 2026-10-08 | plan_scheme.md, stage 4: TinyDrScheme on mini-9pi (`check-drscheme`). mini-ml's code for arm takes seven parameters: `Bigbang.big_bang`'s handlers a record, `text_view`'s x and y a pair (eight compiled and did not link: bugs/ix.md); Enter at the prompt takes the frame's typed text; the draw platform's `fps=off` | 0 | +37 | a function of more than seven parameters, on arm |
| 2026-10-08 | plan_scheme.md: mini-9pi's screen 1024 by 768 (`Swconsole`), the monitor's size said at boot (`Machine.display_size`), and the draw platform's words by Plan 9's default font where they are about its size (`Font`; `font=hershey`) | 0 | +80 | none |
| 2026-10-09 | plan_rio.md: `windows/` in modules as xix's (`Wm`, `Mouse_action`, `Processes_winshell`, `Device`, `Virtual_cons`, `Virtual_mouse`, `Dev_wm`; `Rio` 144 lines for 286), a window's `label`, `cursor`, `winid` and `text` files, the double click (`Terminal.double`); `make check-files` | 0 | +265 (`windows/`: 1,190 lines; `.ml` +100, `.mli` +165, seven of them new) | none; the text edited anywhere (rio's `terminal.c` and `scrl.c`, 1,436 lines) is not to be done |
| 2026-10-09 | plan_rio.md: a window's `wctl` file (`Wctl`: new, resize, move, top, bottom, current, hide, unhide, delete, scroll, noscroll), the windows' files in `/srv` and at `/mnt/wsys`, `$wsys`; scroll and noscroll (a full window that does not scroll holds its program's writes: `P9_server.Later` for a write); `/dev/screen` and `/dev/window` (`Display.file`) | 0 | +228 (`windows/`: 1,418 lines; `.ml` +146), +28 (`Display`), +4 (`P9_server`) | rio's `wctl.c` is 551 lines |
| 2026-10-09 | plan_office.md, stage 1: the kits mini-office stands on, copied from the playground (`Saved`, `Style`, `Rich`, `Page`, `Bitmap`, `Pattern`, `Seed_fill`, `Paint`, `Figure`, `Drawing`; `Packbits` in `lib_compression/`), each made what mini-ml takes: `Rich.of_string`'s style said, `Page.layout`'s three optional arguments a record, `Bitmap`'s `Scanf` line read by hand, an `Option.value ~default` a `match`, a `for _`; the stdlib's `Hashtbl.filter_map_inplace` and `Stack.is_empty` (the call of the first was rewritten out on 2026-10-01; a second program asks) | 0 | +24 (the stdlib: `Hashtbl` +19, `Stack` +5), +1,758 (`apps/office/`'s `document/`, `richtext/`, `paint/`, `draw/`, 20 files; `apps/`: not in m-IX's budget), +103 (`Packbits`) | optional arguments; `Scanf` (OCaml's is 1,500 lines) |
| 2026-10-09 | plan_office.md, stages 2 and 3: what draws and the five parts (`apps/office/shapes/`, `parts/`), `File_menu`, and the platforms' store of documents over the capabilities (`lib_playground/platforms/Store`: `Cap.env`, `open_in`, `open_out`, `readdir`, each used); `Part_text`'s `Scanf` line read by hand, three more optional arguments said; `languages/formula/` and `apps/kits`' sheet moved under `apps/office/` | 0 | +72 (`Store`: `.ml` 46, `.mli` 26), `apps/office/` +1,192 (18 files; not in the budget) | `Scanf` again; four functions in each of four platforms (one module for them) |
| 2026-10-09 | plan_office.md, stage 4: `apps/office/Office.ml`, the playground's TinyOffice: a polymorphic variant a type (`band`), 6 optional arguments said, and a record copied with a field of another type (`{ d with body }` from `'a doc_` to `'b doc_`) written whole, mini-ml giving the copy the record's own type; its 16 sessions the playground's golden frames by OCaml's code, 7 of them one pixel apart by mini-ml's | 0 | `apps/office/` +1,099 (not in the budget) | a record copy's type made anew (Typing: the type's parameters instantiated for the copy) |
| 2026-10-09 | the stdlib a library, and a program the units it uses: `lib_core.a` (mkconfig's `STDOBJS`), the start's names of each unit weak (`Link.weak`, GLOBL's flag 32: no member taken for one, a call to one not defined no call, its address 0), a library's member its bytes, read when taken; `Link`'s instructions kept in one list while objects load. mini-rm 885 KB to 547, its link by mini-ml's mini-ld 7.5 s to 2.6; ix built by ix 91 s to 23, its fixed point 1 min 23 s; in 16 GB and 4 processors the second build's peak 13.1 GB where it was killed at 16. And `float_of_string` passes a number's underscores (the fixed point's second build refused `8_000_000.`: bugs/ix.md) | +21 (the start's weak names 7; the runtime: the roots' test 3, `float_of_string` 11) | +59 (`Link` 41, `Program` 1, the help 5, the mkfiles 12) | the units a program needs computed by mini-ml (ocamlopt's way: the objects' imports read, a closure, ~60), and a `-start` line changed in 28 mkfiles |
| 2026-10-09 | a pattern says where it is in the text (`Ast.pattern`'s `pspan`, as an expression's `espan`): for mini-emacs's colors, which ask mini-ml's parser what a name is (`languages/ml/highlight/Names_ml`, 123 lines, in place of the playground's `Parse_ml`, 1,184) | +2 | +123 | |
| 2026-10-10 | lib_core's `Hashtbl`: `replace` grows the table as `add` (a table filled by it kept its first size: mini-datalog by mini-ml, 10 s for 90,000 tuples), a key compared by `compare` in `find`, `find_all` and `remove` too (plan_prolog.md; `tests/modern/hashtables.ml`) | 0 | +2 | |
| 2026-10-10 | `-flow` and `-dflow`: a function's SSA form as Datalog facts (`facts/Ssa_facts`, 72 lines), and `Alloc`'s liveness a function of its own for it (plan_prolog.md, stage 9) | +88 | 0 | |
| 2026-10-10 | `-facts`: a unit as the facts of which function a call may reach (`facts/Closure_facts`, over `Scope`), for the author's pointer rules (plan_prolog.md, stage 10) | +248 | 0 | |
| 2026-10-10 | mini-prolog's second machine, the WAM (`-wam`, `-S`: `Wam`, `Wam_compile`, `Wam_machine`; plan_prolog.md, stage 5): written in what mini-ml takes (a `for _ =` loop was the one thing refused, written `for _i =`) | 0 | 0 | 1,095 lines of mini-prolog |
| 2026-10-10 | mini-scheme's second machine, Landin's SECD (`-secd`: `Scheme_secd`), written in what mini-ml takes | 0 | 0 | 316 lines of mini-scheme |
| 2026-10-10 | mini-forth (`languages/forth/`), written in what mini-ml takes; it asks itself whether a divisor is zero and an address in the memory, since mini-ml's `/` and its arrays do not raise | 0 | 0 | 662 lines, apart from m-ix as the other languages that are run |

Since `92c9b4e`: +739 in ix (edits +109, new files +630) and +133 in
mini-ml, against ~440 lines mini-ml won't need; and goal 1 reached. `Set_` is also a piece of the
stdlib mini-ml needs to compile ix (decision 9: OCaml's `Set` is a
functor).

So about as many lines saved as added, at best, and only once phase 2
lets mini-ml parse the files; `[%bits]` is worth more for what it
reads like (the manual's diagrams) than for its lines. Hence: phase 2
first, which the second goal needs anyway; then `machine/Arm32.ml`'s
decoder converted and its lines counted, before mlpp grows (deriving
`map`, type classes): a construct that doesn't pay for itself stays
small, or goes.

## Goal 2's census

`languages/ml/tests/compile_ix.sh` (2026-10-01): every `.ml` of ix
compiled by mini-ml (names, types, code), the other units found in its
program's directories and the shared libraries', the stdlib
ocaml-light's. 73 of 265 compile: 70 of the kernel's 72, written in
ocaml-light's dialect, and 3 others. Each file's first error:

| missing | files | |
|---|---:|---|
| labels, parsed and not compiled | 35 | 19 parameters, 16 arguments (decision 5) |
| `int64`, `int32`: no such types | 33 | and their literals; the runtime's primitives |
| the stdlib's functions ocaml-light lacks | 29 | `String.contains`, `String.index_opt`, `Sys.readdir`, `Bytes.get_int32_be`... |
| external libraries | 36 | `Unix` 16, `CapSys` 8, `Fpath` 7, `Re` 4, `Tsdl` 1 (decision 9) |
| dune's library names | 22 | `Ix_asm.Parser`: mini-ml has no library wrapping its modules; decided: ix without the prefixes, its libraries unwrapped (done, 112 of 266 compile) |
| inline records, parsed and not compiled | 14 | (decision 6) |
| `type t = private string` | 9 | one declaration, `Sha1.mli`'s: `private` read as a type's name; decided: an abstract type (done, 111 of 266 compile) |
| a constructor or a label of two types | 7 | `Tvar` is Ast's and Scope's: OCaml takes the expected type's, mini-ml the last declared |
| the stdlib's modules ocaml-light lacks | 2 | `In_channel` |
| `%C` in a format | 1 | |

Done: local open (step 1, 2026-10-01; `tests/modern.sh` runs today's
OCaml by OCaml and by mini-ml: `local_open.ml`, and `sugar.ml` for what
the parser rewrites); `int64` and `int32` (step 2: `boxed_ints.ml`, on
arm64, on arm under qemu-arm, and with the runtime by gcc; the 33 files
that stopped there now stop further, 14 of them at `format4`, the
stdlib's type of a format); labels (step 3: `labels.ml` and
`label_units/`; 81 of 265 compile, no file stops at a label); inline
records (step 4: `inline_records.ml`, `inline_units/`; 85 of 266, and
nothing is "parsed, not compiled yet" anymore); the stdlib ix's own
(step 5a: `lib_core/`, split as xix's; the tests' scripts compile and
link it from there, not from `/tmp/ix-ocaml-light-*`, which is now
only the reference compiler of `types.sh` and of `LIVE=1`).

The stdlib's additions (step 5b), a module at a time, each function's
answers OCaml's (`tests/modern/`): String (`strings.ml`; 92 of 266
compile). For each function, the author asks first whether ix could
do without ("Do we need those functions or could we rewrite ix
instead?"): `String.to_seq` only served `List.of_seq (String.to_seq
s)`, a string's characters, now `List.init (String.length s)
(String.get s)`. `Seq`, which tiny-database's queries and git's
`Query` are made of (lazy rows), is added (the author: "Let's also Add
Seq, we can copy the one from the ocaml 4.14 opam installed stdlib if
needed", "or trim it to what we need"): `lib_core/collections/Seq`,
4.14's definitions of the 11 functions ix uses, of its 77, and none
of its Lazy and atomics (`seqs.ml`). To decide:
`String.get_utf_8_uchar` and
`Uchar.utf_decode_*` (the editor's and diff's UTF-8, 15 uses), OCaml's
API, or a small `Rune` of ix's as xix's commons has.

Then the functions that are plain OCaml, in one step (`stdlib.ml`; 106
of 266 compile): no primitive of the runtime's is new. Then the
runtime's files (step 5c, `files.ml`: on arm64, on arm, and by gcc
with glibc): `sys_open` took no flags, a file was only written. They
are Plan 9's calls (`open`, `create`, `remove`, `dirstat`,
`dirreadall`, `dirwstat`, `getwd`, `fork`, `execl`, `wait`), so where
Plan 9 differs the runtime does: `Sys.rename` is in one directory (ix:
one call, a file and its temporary), `Open_append` a seek to the end
when opened, `Sys.executable_name` the name the program was run by.
Still stubs, no program of ix calling them: `Sys.time`, `seek_in`,
`in_channel_length`; and `Sys.chdir` (one call), which goken's libc
lacks on Linux.

One source for OCaml 4.14 and for mini-ml (the author: "remember that
we want ix's code to compile both with current ocaml 4.14 and
mini-ml", "or for ocaml 4.14 some files may be preprocessed by the
soon mini-ml -pp"): `lib_core/`'s stdlib has OCaml 4.14's names, types
and labels, nothing of its own that ix would call; `tests/modern/`'s
programs are run by OCaml 4.14 first, their output mini-ml's contract.

Then (steps 5d to 5f; 109 of 266 compile): a format's `%ld`, `%Ld`,
`%S`, `%C` (`formats.ml`); the floats (`floats.ml`, arm64: arm has no
floats yet); MD5 (`digests.ml`). The floats' test found mini-ml's
floats were not OCaml's, and now are:

- `=`, `<`... were `compare`'s order, so `nan = nan` held and `x <> x`
  told no nan. The compiled code now calls a relation of the runtime's
  (`ml_equal`, `ml_lessthan`...; Lower's `poly_function`), IEEE's: a
  nan is unordered, in a structure too, so there a value physically
  the same is still looked into, as OCaml's. `compare` keeps its total
  order and its shortcut.
- So `List.mem`, `assoc`, `mem_assoc`, `assoc_opt` are `compare a x =
  0`, OCaml's definition, where ocaml-light's had `a = x`: ocaml-light's
  `boyer` test looks for a term in a list of terms that are cyclic
  (a head's lemmas name the head), and ends only because the term
  found is the very one sought.
- `-. 0.0` was `0.0`, and a nan negated changed its bits: C's `-x` by
  goken's compiler is `0 - x`. Negation and `abs_float` are now on the
  sign's bit; `ceil` and `floor` give their zero the argument's sign.
- `nan` is OCaml 4.14's bits (a signaling one), `infinity` and the
  others of their bits too: no float's instruction when a program
  starts, so arm's programs still start.

A bug of goken's toolchain found on the way (and so of ix's twins,
which give the same bytes): on arm64, `~x` of a 32-bit unsigned is
compiled by 7c as `EORW $0xffffffff, R`, which 7l encodes as an
illegal instruction (a 32-bit mask of all ones has no encoding; it is
`MVNW`). MD5's functions are written without `~`. To fix in goken's 7l
and in mini-ld together.

The bugs, each with how to reproduce it: `bugs/goken.md` (27 to 30),
`bugs/ocaml_light.md` (6, 7), `bugs/ix.md` (mini-ml's).

What is left of the stdlib: `Float.fma` (one call, the emulator's
FMADD of doubles: an instruction on arm64, `fma` in glibc, not in
goken's libc); UTF-8 (`String.get_utf_8_uchar`, to decide);
`Format.pp_print_list`; `Sys.chdir`; marshalling; Lexing's and
Parsing's engines.
Used once, rewritten in ix rather than added: `Option.fold` (a
match), `Hashtbl.filter_map_inplace` (a fold, then `replace`),
`Filename.quote_command` (two `Filename.quote`). Not `Float.fma`
(`machine/Arm64`'s FMADD of doubles): a multiply-add rounded once is
not a line of OCaml (`fma_single` is 10, for singles in doubles); the
runtime's, with the floats' bits.

Type-directed names (step 6). ix's style is the author's: a binding
annotated, `(d : Ast.type_decl)`, and its fields then written without
their module, `d.tname`; OCaml takes the field, or the constructor,
from the type it knows. Measured with OCaml's warnings 40, 41, 42 on
(`OCAMLPARAM='_,w=+40+41+42'`, a dune build): a name of a type not in
scope, 5,198 uses (a field 2,510, a constructor 2,417, a whole record
written or matched 271); a name several types in scope have, chosen by
the type, 6,011; chosen without a type, the last declared, 45. In one
file, two types with the same field or constructor: 38 names, 14
files. So not a rewrite of ix (qualifying 5,000 names, against the
style), a feature, by steps:

- 6a, done: fields read and assigned, as ocaml-light's own backport
  (its `typecore.ml`, `Pexp_field`): Scope finds the field as before,
  or leaves it without a position; Typing, with `r`'s type inferred,
  takes the field of that name in that type (`Scope.type_field`), and
  writes its position in the node for Lower. It needs the type known
  by then: an annotation, or what the function did before; else "the
  field a: its record's type is not known here; annotate the record".
  `tests/modern/fields.ml`; 115 of 266 compile.
- 6b and 6c, done: constructors (`Object.hash (Tree [])`, `function
  Commit -> 1` for an annotated function) and a record written or
  matched whole (`let v : Scope.var = { vname = x; vid = n }`). The
  expected type comes down with the expression or the pattern (the
  author: "I like the idea of extra parameter, expected_type passed
  down"; `want` in the code), in Scope, not in Typing: a constructor's
  arity, which Scope needs to split its arguments, and its tag, which
  Lower needs, are the chosen constructor's. So the expected type is
  only what is written, with no inference: an annotation (a
  parameter's, a result's, a let's), a val's type from its `.mli`, a
  function's from its parameters' annotations, a field's and a
  constructor's argument's (a type's parameters replaced: `kind list`
  for `'a list`), a tuple's; for a `match`, what is written of the
  value matched (a variable's annotation, a field, a call's result).
  Cheap and useful: a call's type variables take what an earlier
  argument says (`k = Commit`, `List.mem k [ Commit ]`, `!r`, `r :=
  v`); `M.C` in a clause or one side of an or-pattern gives its type to
  what follows; `{ M.l = ...; l' = ... }` is of `M.l`'s type; a field
  assigned is under its field's type.
  Where no type is written the name is the scope's, or unbound, and the
  error asks for the annotation (the author: "we don't have to handle
  all the complicated case", "we can also rewrite the code in ix!
  especially if rewriting is simply adding type annotations to toplevel
  functions that anway are good practice"). In ix: 8 annotations, in 5
  files (a local function's parameter, a result, three `let`s, a
  `fun`'s second parameter). `tests/modern/constructors.ml`; 132 of
  266 compile, and no first error is a field's or a constructor's.
  A record written without a type, of two types of the file: the last
  declared that has exactly those fields, as OCaml (added when `Link`
  asked: `sym` and `prog` share `version`).

Step 7 (2026-10-01): what was left of the stdlib, and the first two
libraries. Not the tests (the author: "let's not compile testing code
with mini-ml for now": they are Testo's and Alcotest's): `compile_ix.sh`
leaves `*/tests/` out, 251 files. Of them 197 compile.

- `Fpath`: ix's own for mini-ml, `lib_core/system/Fpath`, the 12
  functions its programs use (`v`, `to_string`, `/`, `//`, `base`,
  `parent`, `set_ext`...), inspired by Daniel Bünzli's library and held
  to its answers (`tests/modern/paths.ml`, run by OCaml with the real
  fpath, then by mini-ml with this one). dune's builds still take the
  library: the directory is not dune's.
- `Cap`: erased (the author: "its code is using objects that anyway we
  don't want to handle in mini-ml", "let's just erase it and drop its
  use like we do in ocaml-light"). A capability's type, `< Cap.stdout;
  .. >`, was already one type for mini-ml; `Cap.main f` is `f` of
  nothing, `CapSys.argv caps` is `Sys.argv`. The capabilities are still
  passed and written, for the reader and for OCaml.
- With 46 files past `Fpath`, more names needed their type written:
  13 annotations and 2 rewrites in ix, and the expected type extended
  (step 6d in the ledger) where an annotation would have been noise.

`Logs` (step 7d): a poor man's, as xix's, with the real library's
interface for what ix calls, `Logs_fmt.reporter` and `Fmt`'s two names
included so that `Logging` is not written twice; its output is the
library's (`tests/modern/log_levels.ml`). 201 of 251 compile.

`Unix` (step 8; the author: "a very common ocaml library we will want
to handle in mini-ml, and to work both with gcc and goken's own libc",
"and compiled by mini-C"). Not C stubs over a libc, which would be
written twice (Plan 9's calls for goken's, POSIX's for glibc) and
would not be Unix's anyway on Plan 9's: `lib_core/system/Unix.ml` is
OCaml, each function a system call of Linux's by its number (arm's and
arm64's), through one primitive, `unix_syscall nr args`: an argument an
int, a string or bytes (their address), an int32 or an int64. The
kernel's structures are bytes packed and read there (`statx`'s, the
same on every machine; `getdents64`'s entries, a `sockaddr`, a
`termios`, `ppoll`'s descriptors for `select`). The runtime's part is
57 lines, with `execve`'s two arrays; under gcc the call is glibc's
`syscall`, under goken's its `_syscall6`. `tests/modern/unix_calls.ml`
and `unix_sockets.ml` are run by OCaml with its Unix, then by mini-ml:
the same lines, with goken's libc on arm64 and with glibc on arm (the
runtime by gcc). What differs from OCaml's: a label optional there is
given here (`Unix.pipe ~cloexec:false ()`, 3 calls in ix changed);
`getaddrinfo` has no resolver (a numeric address, `localhost`,
`/etc/hosts`); a terminal's speeds are read, not set; it is Linux's
only. Found on the way: 7c's `long` is 32 bits on arm64 (Plan 9's), so
a pointer through a `long` lost its half; and the seconds since 1970
don't fit arm's 31-bit int. 237 of 249 compile.

What stops the 12 others: `Re` (7), the kernel's `Memdata` (2),
`Filename.temp_file ~temp_dir` (an optional argument of OCaml's
stdlib, `database/Shell`), `Marshal.from_bytes` (tiny-database), and
`Lexing`'s positions (mini-ml's own `CLI`).

Marshal (step 9; the author: "Marshal is a pretty fundamental
feature"): ix's objects and libraries are marshalled values
(`Asm.save`, `Link`'s libraries), and tiny-database's pages. The
module was there, an interface: its primitives in the runtime were
stubs. Now OCaml's format (ocaml-light's too; the author: "being
compatible with what ocaml 4.14 does is also nice"), not ocaml-light's
code, which is for its heap: a header of 20 bytes, then the value
depth first, an integer by its size, a string, a block by its tag and
size, a float, an int32 or int64 as OCaml's custom blocks, and a block
met before by how many objects ago. Read back in one piece: the
header says the words needed, the heap makes room for them once, and
no block moves while the value is built (the C's; since 2026-10-07
Marshal is ML, `lib_core/core/Marshal.ml`, and its blocks are the
collector's as any: plan_ml_features.md, 3). `tests/modern/marshalled.ml`
prints the bytes: the same as OCaml 4.14's on arm64, for integers,
strings, variants, records, arrays, floats, int32 and int64, shared
and cyclic values. Not the same blocks, so not the same bytes: a
constructor's inline record (here a block of its own: the optimization
to do, "Later: optimizations"), an array of floats (here boxed); a
closure is refused; on arm an integer of more than 31 bits. 238 of
249 compile.

2026-10-02: `Re` is gone (only `builder/Pattern` named it, for mk's
`:R:` rules: now ix's `Regex`, which is libregexp's algorithm, as the
original mk's; its 6 dependents compile), `Filename.temp_file`'s
`~temp_dir` too, and the census finds the kernel's `Memdata`. 248 of
249 compile: what is left is mini-ml's own `CLI`, for `Lexing`'s
positions. Next (the author): mini-lex and mini-yacc, reading
ocamllex's and ocamlyacc's files, their engines in OCaml (no C engine
in the runtime), from xix's `generators/`; a plan first.

2026-10-02, later: every file compiles, **249 of 249**, with `Lexing`
and `Parsing` written again (plan_lex_yacc.md, step 1). Goal 2's
first half is reached: each file of ix, alone, goes through mini-ml.
The second half is programs linked and run, which needs mini-lex and
mini-yacc (that plan), then mkfiles.

Out of mini-ml's reach, with the tests: what needs SDL (`Tsdl`:
mini-qemu's window, `raspberry/Sdl_display`, and its `Main`, which
opens it), and the playground (js_of_ocaml); the author: "it would
require too many things". `compile_ix.sh` leaves the two files out:
249 files.

Then (before `Unix`) what stopped the 48 others: `Unix` (38) and `CapUnix` (1), `Re` (6), the
kernel's `Memdata` (2); and `Lexing`'s positions
(`lex_curr_p`, `pos_fname`, `new_line`: ocaml-light's Lexing has none),
which mini-ml's own `CLI` and every ocamllex lexer of ix need, with
the runtime's `lex_engine` and `parse_engine`.

First errors: others are behind them. The steps, one at a time, each
reviewed by the author before its commit ("one step at a time, let's
add a feature and let me review before commit each time"): local open
`M.( )` in Scope; `int64` and `int32`; labels; inline records; then
the libraries' names, the stdlib, the libraries.

## Phasing

0. **The census**: `ix_features.py`, `parse_ix.sh` (done, 2026-09-30).
   To add: labels given out of order or partially, and optional
   arguments omitted (decision 5).
1. **mlpp's skeleton** (decision 7): `mini-ml -pp` printing a file
   back, its test over ix's files; dune wired on a program
   (`tests/pp/shapes/`), merlin checked on it (all done).
2. **The cheap sugar** (decision 8); `parse_ix.sh`'s count going down.
3. **mlpp's `type t = _`** (decision 1), then applied: the 273 lines.
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

## Later: optimizations

What was done the simple way, to do better when a measure asks (the
author: "we can maybe remember somewhere the list of possible further
optimizations"). Each beside the simple version, switchable, the old
code kept under `(* old: *)`, as ix's optimizations are
(`languages/ml/opti/`, `plan_ml.md`'s phase 7).

| what | today | better | where | when |
|---|---|---|---|---|
| inline records (decision 6) | `C` points to a record's block: 2 allocations, 1 indirection more | the fields in `C`'s block, as OCaml | Scope (the labels' positions) and Lower (`C r`, a view of the block) | the emulators' decoders compiled: an instruction decoded is one |
| `match ... \| exception` (decision 8) | a closure built and called at each match | the value's clauses after the try's exit, no closure: a node of its own, lowered as a try | Parser, Scope, Lower | measured in a loop |
| `o \|\|\| d` (`Common`) | a call | inlined: a test and a branch | Opti (small functions inlined) | with inlining at all |
| `3L`, `Int64.add` (step 2) | a block and a C call for each operation | on arm64 an int64 in a register between operations, boxed only when stored; the literals shared | Lower, Opti | `machine/Arm64.ml` compiled: its registers are int64 |
| `[%bits]` patterns (decision 2) | a test per run of fixed bits, a shift and a mask per field, the fields in the guard computed again in the body | one mask and one comparison per clause; a clause's tests shared with the next's (a decision tree) | `pp/Bits`, or Opti on its output | a decoder's time measured |
| a derived printer (decision 3) | strings concatenated with `^` at each node | a Buffer passed down | `pp/Derive` | a large tree dumped |
| a call's labels (decision 5) | nothing at run time | (none: Scope's) | | |
| `=`, `<` on floats (step 5e) | a call of the runtime's relation, the two boxes read; a value equal to itself looked into (a nan may be in it) | the comparison inline where Typing knows the two are floats; the shortcut back where the type has no float | Typing's types kept to Lower, Opti | a float loop measured |
| `Set_`, mini-ml's allocator's sets | balanced trees | bit sets for registers | `ssa/Alloc` | its time in a large function |
| `mini-ml -pp` | the file parsed, rewritten, parsed again when compiled | the tree rewritten, parsed once | CLI, `pp/` | never, probably: a file is small |

## A list comprehension: `[%list e || x <- xs; c]` (2026-10-04)

The author: "could we add another mini-ml -pp extension, like list
comprehension? Again more like showcasing the feature than really
saving lines". Haskell's `[ e | x <- xs, y <- ys, c ]`, written so that
the file stays OCaml's syntax (ocamlformat, semgrep's parser and merlin
read it): `||` for the bar, `;` between the qualifiers, and a generator
`x <- xs`, which OCaml's grammar has for an object's variable.

```ocaml
[%list (a, b, c) || a <- range 1 n; b <- range a n; c <- range b n; a * a + b * b = c * c]
```

is rewritten to

```ocaml
(range 1 n : _ list) |> List.concat_map (fun a -> (range a n : _ list) |> List.concat_map (fun b -> ...
  if a * a + b * b = c * c then [ (a, b, c) ] else []))
```

- A qualifier is a generator or a condition; the first one is a
  generator. A later generator's list may name an earlier variable.
- A generator's variable is a name, not a pattern (`(a, b) <- pairs` is
  not OCaml's syntax).
- The list comes first (`|>`), so that the variable's type is known in
  what follows, and is constrained to a list, so that what is not one
  is an error at its place in the source (`tests/pp/errors/generator.ml`).
- Its parts may not hold another of mlpp's constructs.
- In mini-ml: 45 lines (Pp's `comprehension` 25, Ast 4, Parser 5,
  Resolve 2, and a string token's span fixed in the lexer). Used once,
  in `builder/CLI.ml` (`-w`'s names).

## A lazy "or else": `a |! b` (2026-10-05)

`Common`'s `|||` gives an option's value or a default, which is
evaluated in any case. Where there is no default, the code said
`match e with Some x -> x | None -> error ...` (about 130 times).
mlpp's `e |! f` is that match: `f` is evaluated only when `e` is
`None`, so it may raise.

```ocaml
let fk = stat f |! fatal "cannot stat %s" f in
```

- `|!` is an infix operator in OCaml's grammar (a comparison's
  precedence), so the file parses everywhere; without mlpp it is an
  unbound value. `!` because what follows is most often an error (the
  author: "a lazy one and error oriented"); `?|`, his first spelling,
  is a prefix operator in OCaml.
- The rewrite puts text around the two operands and leaves them in
  place, so they may hold other constructs (not so inside a `[%list]`,
  whose parts are copied).
- 15 lines in mlpp. Used in mini-git (`version_control/`, whose dune
  library mlpp now reads), mini-mk and mini-5i: 20 places. A default
  that is a value stays `|||`.

For options in sequence, mini-ml now reads OCaml's binding operators
(`let*`, `let+`...: `( let* ) e (fun x -> body)`, in the parser, 6
lines), and `Common` has `let*` as `Option.bind`.

## Type classes: `[@@class]`, `[@@instance]`, `[%using: 'a show]` (2026-10-05)

The author, on the design below: "ok I love this, let's do it! would be
nice if those had a different syntax in the type, like in haskell with
Show a => .... Scala 3 learned that Scala 2 implicits had some issues,
so maybe there are lessons we can learn from Scala 3"; "maybe we can
also have a lib_core/commons/Prelude.ml imitating Haskell typeclasses!
so one doing open Prelude clearly indicates the new style of
programming"; and "we do want to have ocamlformat, merlin, still work,
so that's the advantage of this very lightweight syntax".

Haskell's classes as **dictionaries the calls don't write**. What
declares is plain OCaml with three marks; mlpp's one job is to write
the dictionary at each use, from the types.

```ocaml
(* a class: a record type *)
type 'a show = { show : 'a -> string } [@@class]

(* instances: values of it; one with a constraint has a dictionary of its own *)
let show_int : int show = { show = string_of_int } [@@instance]
let show_list [%using: 'a show] : 'a list show =
  { show = (fun xs -> "[" ^ String.concat "; " (List.map show xs) ^ "]") }
[@@instance]

(* a function with a constraint: Haskell's (Show a) => a -> IO () *)
let print [%using: 'a show] (x : 'a) = print_endline (show x)
let () = print [ 1; 2 ]
```

and in a `.mli`, `val print : [%using: 'a show] -> 'a -> unit`. mlpp's
output:

```ocaml
let show (d__ : ('a show)) = d__.show                       (* after the class *)
let show_list (_u345 : 'a show) : 'a list show = { show = (fun xs -> ... (List.map (show _u345) xs) ...) }
let print (_u626 : 'a show) (x : 'a) = print_endline (show _u626 x)
let () = print (show_list show_int) [ 1; 2 ]
```

- **`[%using: t]`**, a parameter's type, in a `val` and in a
  definition, where it is a parameter without a name (or, named, `(d :
  [%using: 'a show])`, then `d.show x`). Haskell's `=>` is not OCaml's
  syntax; an extension node is, and ocamlformat keeps it as written
  (checked: `[@@class]`, `[@@instance]`, `[%using: ...]` in a `.ml` and a
  `.mli`). The word is Scala 3's.
- **`[@@class]`** derives a function for each field, of the dictionary:
  `show`, in the `.ml` and in the `.mli` (Derive's `accessors`). So a
  method is a function with a constraint like the others.
- **A dictionary is found from the type its class is at**, when its
  toplevel definition is typed: a type's constructor, the class's
  instance for it, whose own dictionaries are found the same way
  (`show_list (show_pair show_string show_int)`; an abbreviation, what
  it stands for); a type variable, the `[%using]` parameter of the
  function around at that variable. **No constraint is inferred**: a
  function that needs a dictionary says so (the author's rule: annotate
  rather than a cleverer checker), and `let twice x = show x ^ show x`
  is the error "show of a type not known here: annotate it, or give the
  function the parameter [%using: 'a show]".
- **One instance for a class and a type, in the unit of one of the
  two** (Haskell's rule against orphans). So finding one reads those two
  units' interfaces, there is no table of a whole program, and what a
  file opens or names changes nothing. The dictionary is written by its
  full name, `Prelude.show_list Point.show_point`.
- An instance that uses itself is a `let rec` (`show` at `'a list` in
  `show_list` is `show_list` itself); a function that calls itself has
  its dictionaries in its own body (Typing's `shape`).
- An operator may be a class's: `a == b` is written `(( == ) eq_int (a)
  (b))` (the parser gives an infix operator its own place in the text).
  Not a prefix one (`!x`, `-x`), nor a field's punning (`{ show }`).

**From Scala 3**, which redid Scala 2's implicits:

| Scala 2's trouble | Scala 3 | here |
|---|---|---|
| one word, `implicit`, for a parameter, an instance and a conversion | `using`, `given`, `Conversion` | `[%using]`, `[@@instance]`; no conversion |
| a value of any type could be implicit (an `Int`, a `String`) | (still) | only a `[@@class]` type's |
| an instance came with a wildcard `import`, unseen | `import x.given` | by the class's and the type's units only, never by an `open` |
| a local name hiding an implicit's silently removed it; nesting and priorities | by type, a simpler order | a constructor: the instance, always; a variable: a `[%using]` parameter, and no other local value |
| an implicit's type left to inference | a `given`'s type is written | an instance's type is written (an error if not) |
| "could not find implicit value" | better messages | "no instance of show for float", at its place (below) |
| a dictionary passed by hand looked like any argument | `f(x)(using d)` | not yet: `f [%using d] x` is kept for it |

**How**: two rewrites of the text. The first is mlpp's sugar, as
before (a class's methods are derived there). The second needs the
names and the types: mini-ml's Resolve and Typing run on the first's
tree, with the dictionaries left out (`Resolve.implicit`), and Typing,
where a name's type has `[%using]` parameters, takes them off and keeps
them wanted; a definition typed, each is found (`Typing.dictionary`) as
text, which `Pp.classes` writes after the name. mini-ml compiling reads
that text again, where the dictionaries are arguments like the others:
one implementation, and mini-ml's own Typing checks it. `[%using: t]`
is a type, `t using`, an abbreviation of `t` that only that search
reads.

- **`-pp` reads the other units' interfaces**, the stdlib's too:
  `-I`, or `-L lib_core` (the directories of its `units.txt`, and
  `commons/`). A unit with no class in sight is as before: its names
  resolved once, nothing typed twice; under dune, a library that
  doesn't pass `-L` is not even resolved.
- **A class across units needs the `.mli`**: a unit without one gives
  its values no types.
- **Errors are OCaml's, at their place** (merlin). `-pp` is lenient: a
  dictionary not found is written `[%ocaml.error "no instance of show
  for float"]`, which OCaml and merlin report on that line; a
  definition with a type error keeps the dictionaries found and OCaml
  says the error itself (mini-ml's is a warning on stderr). Compiling,
  mini-ml stops at either.
- **The columns** are kept as for the other constructs: what follows a
  dictionary goes to the next line, after a `#` line, at its column.
  `Pp.position` now reads the first rewrite's `#` lines.
- **merlin, checked** (`tests/pp/prelude/main.ml`, through dune): no
  error; a name's type on hover before and after the dictionaries of a
  line (`show`: `'a show -> 'a -> string`); go-to-definition of `show`
  to `Prelude.mli`'s class; "no instance of Prelude.show for a
  function" where a `show (fun x -> x)` is typed in. dune tells merlin
  `-L ./lib_core`, from the workspace, and merlin runs it in the
  source's directory: `-L` looks in the directories above too.
- **Typing, for all**: a type variable's name in an annotation is now
  one type in its whole toplevel definition, as OCaml's (`(x : 'a)` and
  `[%using: 'a show]` are the same `'a`; they were two).
  `types.sh` and `compile_ix.sh` as before.
- **Not done**: classes over type constructors (Functor, Monad: no
  higher kinds), a class above another (`eq` for `ord`), default
  methods, an instance in a function, a dictionary passed by hand.

**Prelude** (`lib_core/commons/Prelude`, dune's `ix_prelude`, apart
from `ix_core`, which mini-ml is made of): `show`, `eq`, `ord`; `==`,
`/=` and `!=`, `compare`, `sort`, `maximum`, `minimum`; the instances at
int, bool, char, string, float, unit, int64, list, array, option, pairs
and triples. `open Prelude` changes what `compare`, `==` and `!=` mean;
`<`, `max`... stay OCaml's (through a dictionary, a call each). No
`print` (a capability's) and no `num` (below).

**Its tests** (`pp.sh`, by OCaml and, `MINI_ML=1`, by mini-ml):
`classes.ml` (instances of lists, options, pairs, a tree; functions
with one and two constraints, one calling itself; a class's operator),
`classes_units/` (a class in a unit, a type and its instance in
another, `type t = [%mli] [@@class]`), `prelude/` (Prelude, and through
dune); `errors/`: no instance, no dictionary, two instances, a type
error after a dictionary.

**Where ix would use them** (the author: "any places in ix that could
benefit from the use of typeclasses?"; a survey of the 478 `.ml`,
2026-10-05, counts by grep): few.

| place | what | verdict |
|---|---|---|
| `linker/CLI.ml`'s `'m machine` | a record of functions indexed by the instruction's type (`Arm.op`, `Arm64.op`), its fields passed by hand (`~decode:m.decode`, `Link.show m.show p`): ~16 calls | the one fit; ~5 lines |
| Int64, Int32 arithmetic | ~190 lines spell `Int64.add`...; 90 use `I64.( )` | a `'a bits` class would be a call through a dictionary in the emulators' loops; `I64.( )` used more widely does the same |
| printers | 30 derived types, 32 `show_*` by hand | those by hand are syntaxes (assembly, SQL, C), not dumps; `show v` saves a prefix |
| `List.sort compare` (47), `Hash.compare h Hash.zero = 0` (26) | | a word saved; a `Hash.is_zero` |
| `Binary`, `P9_wire` | by width and byte order, all on `int` | not by type: `[%bytes]`'s |
| `Dev.t`, `P9_server`, `Host_calls`, the C compiler's `backend` | records of functions | chosen by a value at run time, not by a type |

So, as `[%list]`, a showcase of what mlpp can do more than lines saved
(`plan_ml_features.md` had them "not worth a construct"), at +520 lines
in mini-ml where the first sketch said 700 (below).

## Later: mlpp beyond sugar

mlpp is where ix's ML can grow past OCaml without mini-ml's compiler
growing:

- **Type classes**: done 2026-10-05, differently (the section above:
  no constrained type schemes, the declarations plain OCaml). The first
  sketch: single-parameter, over types (`'a show`, `'a eq`,
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
- **Deriving a class's instances** (the author, 2026-10-05: "we might
  want also at some point for deriving to derive those instances
  too"): `[@@deriving show]` giving `show_t : t show [@@instance]`, a
  parameter's printer a `[%using]` dictionary and not `poly_a`; and
  `eq`, `ord`.
- **`[@@deriving map]`**, and other derivings, when the numbers justify
  them (decision 3).
- The census after these were in use, and its candidates (`[%bytes]`,
  mini-yacc's parameterized rules, the runtime in ML):
  [`plan_ml_features.md`](plan_ml_features.md).
- Whatever a later census finds: mlpp is the place to try a construct,
  since its output is OCaml, and dropping it means printing that
  output once and keeping it.

## Out of scope

- **Type classes in mini-ml**: they are mlpp's ("Type classes", above).
- **Functors, first-class modules, GADTs**: ix doesn't use them, except
  3 `Make`s, rewritten.
- **Implicit capabilities**: 966 lines name `caps`, and that is the
  point.
- **Compiling the tests**: Alcotest and Testo stay OCaml's.

## What is left

For a plan of their own, or the next one's, if they are wanted:

- **"Later: optimizations"**: the table of what was done the simple
  way (inline records, `match ... | exception`, int64 on arm64,
  `[%bits]` as a decision tree, a derived printer's buffer), each
  waiting for a measure; `plan_mini_toolchain_optimization.md` is
  where the speed is followed.
- **"Later: mlpp beyond sugar"**, and `plan_ml_features.md`'s
  `[%bytes]`.
- **What is left of the stdlib** ("Goal 2's census": `Float.fma` and
  what follows it there).
- **The tests**, which stay OCaml's (Alcotest, Testo): out of scope
  here, and not compiled by mini-ml.
