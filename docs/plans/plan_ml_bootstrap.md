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
| 2026-10-01 | not for mini-ml, but fewer lines for it to compile: tiny's real architecture arm64 only, tiny-arm without its assembler (plan_tiny_arm64.md) | | -375 | |

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
no block moves while the value is built. `tests/modern/marshalled.ml`
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
