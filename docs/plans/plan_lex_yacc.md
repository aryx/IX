# Plan: mini-lex and mini-yacc, the lexer and parser generators (`generators/lex/`, `generators/yacc/`)

Companion of [`plan_ml_bootstrap.md`](plan_ml_bootstrap.md), whose
goal 2 (mini-ml compiles ix) stops here: 248 of the 249 files compile,
and the last, mini-ml's own `CLI`, wants `Lexing`'s positions; behind
it every lexer and parser of ix wants the two engines, which mini-ml's
runtime has as stubs. The author (2026-10-02): "maybe we can first do
a mini-lex and mini-yacc! and uses that! which would then produce code
where we could design our own LexingMini and ParsingMini. Those
mini-lex and mini-yacc could even generate both C code and OCaml code
so they could be used to write parser for both C and OCaml. Note that
I started one in ~/xix/generators/ we could maybe use as a starting
point", and "maybe we can make mini-lex and mini-yacc compatible with
ocamllex and ocamlyacc so we can use them only when using also mini-ml".

Reviewed by the author 2026-10-02: `Lexing` and `Parsing` as the run
time's names ("it's the same name than the one used by OCaml so it
actually keeps the existing code compatible, and allows Lexing.lexeme
calls in the lexers"), written new, `mini-lex` and `mini-yacc`
("consistent with the rest"), C output later ("but let's keep it in
mind as we write the code, to leave space for further extensions"),
the readers by hand ("especially if it's small"), and `generators/`
kept as the directory (decision 9). Step 1 is
done. Was to look at especially: **decision 2** (the run-time modules keep the names
`Lexing` and `Parsing`), **decision 4** (how `as` is done without
ocamllex's tagged automata), **decision 6** (what "the same parser as
ocamlyacc's" is held to), and the open questions at the end.

## Context

What ix has, measured 2026-10-02 (`git ls-files '*.mll' '*.mly'`,
`ocamlyacc -v`):

| file | lines | | |
|---|---:|---|---|
| `database/Lexer.mll` | 90 | 3 rules | `as` on a whole clause and inside it |
| `languages/ml/Lexer.mll` | 143 | 6 rules, 4 with a parameter (`comment depth = parse`) | 7 named regexps, `as` in 12 clauses, one under a `?` |
| `database/Parser.mly` | 389 | 251 states, no conflict | no precedence |
| `languages/c/Parser.mly` | 574 | 401 states, 2 shift/reduce | 17 precedence lines, 1 `%prec` |
| `languages/ml/Parser.mly` | 558 | 530 states, 44 shift/reduce | 24 precedence lines, 26 `%prec`, 2 start symbols |

mini-cc's lexer is written by hand (`languages/c/Lexer.ml`, 201
lines); the assembler's, the shell's and mk's too. None of the three
grammars uses `error`. What their OCaml code calls of the run time:
`Lexing.lexeme` (17), `new_line` (6), `from_string` (3),
`lexeme_start`, `lex_curr_p` and a position's `pos_fname`, `pos_lnum`,
`pos_cnum`; `Parsing.Parse_error` (5), `symbol_start_pos`,
`symbol_end_pos`, `rhs_start_pos`, `rhs_end_pos`.

What exists:

- **OCaml's own.** ocamllex is 3,034 lines of OCaml (its `as` is by
  tagged automata, the larger part); ocamlyacc is Berkeley yacc, 6,583
  lines of C. Their engines are C, in the runtime (ocaml-light's
  `lexing.c` 119 lines, `parsing.c` 304).
- **`~/xix/generators/`** (2,741 lines). `lex/` is ocaml-light's, that
  is OCaml 1.07's: regexps to a DFA (`Lexgen`, 339), the tables
  compacted (`Compact`, 160), written for the C engine (`Output`, 293);
  it has no `as` and no rule parameter, which ix's two lexers use.
  `yacc/` is the author's (2015): LR(0) (216), FIRST and FOLLOW (206),
  SLR (95), a dump; `Lalr.ml` is empty, precedences are a TODO, and
  the three grammars need both.
- **goken's** `generators/lex` and `yacc`: Plan 9's, in C, 6,424 lines.
- **ix's `Regex`** (`lib_core/commons/`, 275 lines): regexps with
  captures, leftmost-longest, a Pike VM.

So xix's is a starting point for its structure and its algorithms'
names, not a base to extend: what ix needs most (`as`, parameters,
LALR(1), precedences) is what it lacks.

## Goals

1. **mini-lex and mini-yacc read ocamllex's and ocamlyacc's files**, the
   part ix's five files use, and write a `.ml` that does what
   ocamllex's and ocamlyacc's does: the same tokens, the same trees.
   dune keeps ocamllex and ocamlyacc; a build by mini-ml uses these.
2. **No C engine.** The generated code runs on `Lexing` and `Parsing`
   written in OCaml, in `lib_core/parsing/`; mini-ml's runtime gets
   nothing.
3. **Small**: about 1,000 lines for the two (xix's is 2,741 without
   what is missing; OCaml's are 9,600).
4. Later, **C output** from the same tables, for goken's and
   principia's C programs.

Not goals: ocamllex's and ocamlyacc's whole languages (`shortest`,
`refill`, `error` recovery, `%token` aliases), their tables' bytes,
menhir's features.

## Decisions

### 1. The input is ocamllex's and ocamlyacc's, read by hand

One source: the five files stay as they are, and stay dune's. The
subset is what a census finds in them (`generators/tests/census.sh`,
kept in the repo): for a `.mll`, the header and trailer, named
regexps, rules with parameters, clauses of characters, strings,
classes with ranges and `^`, `_`, `eof`, `* + ? |`, parentheses, `as`;
for a `.mly`, the header, `%token` with a type, `%left %right
%nonassoc`, `%start`, `%type`, rules with `$n` and `%prec`, the
trailer. Anything else is an error that names the construct, not
something skipped.

The two readers are written by hand (about 120 lines each), not with
ocamllex and ocamlyacc: the generators would otherwise need themselves
to be built by mini-ml, and both formats are a few keywords around
OCaml code copied as it is (braces matched, strings and comments
skipped). This is the exception the author's rule allows ("hand-write
only regular/line-oriented ones, justify with LOC"); confirmed.

### 2. The run time: `Lexing` and `Parsing`, in OCaml, under their names

Decided: `Lexing` and `Parsing`. The actions in
the five files say `Lexing.lexeme lexbuf`, `lexbuf.lex_curr_p`,
`Parsing.symbol_start_pos ()`, and they are one source for both
builds: so for mini-ml the modules must answer to `Lexing` and
`Parsing`. Proposed: `lib_core/parsing/Lexing.ml` and `Parsing.ml`
(today ocaml-light's, 547 lines, with no positions and two C engines)
are written again, OCaml 4.14's interface for what ix calls, plus the
entry the generated code calls (`Lexing.engine`, `Parsing.run`), the
engines in OCaml. Done (step 1): 183 lines for the two, 292 with their
interfaces, where ocaml-light's were 796 and two C engines; the
runtime's two stubs are gone. As `Fpath` and `Unix`:
mini-ml's own, with the real ones' names. dune's builds keep OCaml's
stdlib and ocamllex's output, and never see these.

They are plain OCaml, so OCaml compiles them too: a test puts them in
the stdlib's place (`modern.sh`: a program whose first line is `(*
shadow: lib_core/parsing *)`), and mini-lex's and mini-yacc's output
will be run so, by OCaml, against ocamllex's and ocamlyacc's, before
mini-ml links anything.

For C later (decision 8): the tables are strings of 16-bit numbers and
the two engines are loops over them with nothing of OCaml's in their
shape, so a C engine is the same loop and the same bytes.

### 3. mini-lex: a DFA in a table, an interpreter of it

Regexps to an NFA (Thompson), to a DFA by subsets, one automaton for a
rule's clauses, the earlier clause winning a tie, the longest match
kept (the last accepting state remembered). The table is state ×
character, not compacted: ML's lexer is a few hundred states of 257
entries, written as a string. Compaction (ocamllex's base, check,
default) is the optimization for later, separate and switchable, as
the author's style has it. The generated file: the header, the tables,
a function a rule with its parameters, `match Lexing.engine tables
state lexbuf with 0 -> action0 | ...`, the trailer.

### 4. `as`: a second, small pass over the lexeme

ocamllex computes the bindings while the DFA runs, with tags and
memory cells: most of its 3,000 lines. Here the DFA finds the lexeme
and the clause; then, only for a clause with `as`:

- `r as x` over the whole clause is the lexeme, `_ as c` its
  character: no pass;
- else the clause's regexp is matched again on the lexeme alone by a
  matcher with captures (ix's `Regex`' algorithm on mini-lex's own
  tree, about 60 lines in `Lexing`), which gives each `as` its span;
  a binding under `?` or `|` is an option, one of a single character
  a `char`, as ocamllex types them.

The cost is a second look at the lexemes of those clauses (strings and
integers with a suffix, in ML's lexer). Where two ways of matching
give different spans, ocamllex has a rule (the tags' priorities); here
the matcher's (leftmost, then longest for each sub-expression). The
test of decision 6 says whether they agree on ix's lexers; if not, the
clause is rewritten in the `.mll`, both tools then agreeing.

### 5. mini-yacc: LALR(1) on the LR(0) automaton, precedences as yacc's

- The LR(0) sets of items; the lookaheads by propagation from the
  kernels (the dragon book's algorithm 4.63: spontaneous and
  propagated lookaheads, to a fixed point), not canonical LR(1) sets
  merged, which are thousands for ML's grammar.
- A conflict as yacc decides it: by the rule's precedence (its last
  terminal's, or `%prec`'s) against the token's, then associativity;
  without precedences, shift before reduce, and the earlier rule
  between two reductions. The conflicts left are counted and printed,
  as ocamlyacc's.
- No `error` token: the first unexpected token raises
  `Parsing.Parse_error`, which is all ix's grammars ask.
- Tables state × symbol, not compacted (530 × about 250 entries for
  ML); compaction later. Default reductions are not an optimization
  and are in from the start: a state whose only action is a reduction
  takes it without reading the next token, or a shell reading
  statements (mini-chidb's) would wait for the line after to run this
  one.
- The semantic values on a stack of `Obj.t`, as ocamlyacc's; an action
  a function of the stack; `$n` a typed read (`%token <t>` and `%type`
  give the types, a non-terminal's without one is left to inference
  through a `let _n = ... in` as ocamlyacc does).
- `-v` writes the states, their items and their actions.

### 6. The contract: the same tokens, the same trees, the same automaton

Three levels, each a script under `generators/tests/`:

1. **Tokens.** For each `.mll`, every file of a corpus (for ML: ix's
   600 `.ml` and `.mli`; for SQL: chidb's corpus) lexed by ocamllex's
   lexer and by mini-lex's, the tokens printed with their positions:
   no difference.
2. **Trees.** The same files parsed by the two parsers, the trees
   dumped (`mini-ml -dast`, mini-cc's `-x`, the database's shell):
   no difference. And the programs' own tests pass with the generated
   files swapped in.
3. **Automata.** mini-yacc `-v` against `ocamlyacc -v`: the same
   number of states (251, 401, 530) and of conflicts (0, 2, 44), and,
   the states put in one order, the same action for each state and
   token. This is what says "the same parser" beyond the corpus.

Not the tables' bytes: theirs are compacted, ours not.

### 7. Who builds what

- dune: ocamllex and ocamlyacc, as today. mini-lex and mini-yacc are
  two more programs of ix (`generators/lex/`, `generators/yacc/`), built by dune, tested against them.
- A build by mini-ml: mini-lex and mini-yacc, compiled by mini-ml (they
  are plain `.ml`, their readers by hand), make `Lexer.ml` and
  `Parser.ml`, which mini-ml compiles with `lib_core/parsing/`.
- The fixed point, for the bootstrap: the generated files are the same
  bytes whether the generators were built by OCaml or by mini-ml.

### 8. C output, later, with room left for it

The tables are the same; the actions are C, copied as they are; the
engine is C (about 100 lines for the two). Which input then: this
plan's (ocamllex's syntax around C actions), or Plan 9's lex and yacc
files, whose twins mini-lex and mini-yacc would then be for goken's
programs? Open: it decides whether these are twins of ocamllex and
ocamlyacc only, or of Plan 9's too. Nothing before step 5 depends on
it.

### 9. The directory: `generators/`

`generators/lex/` and `generators/yacc/`, xix's names. The author
wanted a better name; `languages/lex/` and `languages/yacc/` were
proposed (lex and yacc are languages, mini-lex and mini-yacc their
compilers) and refused: "not a fan of putting them in the same
category than c/ and ml/, especially if later we add scheme/ in there,
and prolog/. let's keep generators/ then, and maybe we will have more
code generators in there too later".

## Phasing

Each step reviewed by the author before its commit.

0. **The census**: the constructs of the five files, and of the run
   time's calls; the corpus scripts with ocamllex's and ocamlyacc's
   output as the reference (the token and tree dumps).
1. **`Lexing` and `Parsing`** in `lib_core/parsing/`: the positions,
   the two engines in OCaml, against hand-made tables. Done
   (2026-10-02): `tests/modern/engines.ml`, a lexer and a parser of
   sums on tables written by hand (tokens across two refills,
   positions, syntax errors), the same lines by OCaml and by mini-ml,
   arm64 and arm. mini-ml's `CLI` compiles: 249 of 249.
2. **mini-lex** without `as` beyond the two free cases; then `as`.
   Tokens the same on the two corpora.
3. **mini-yacc**: LR(0), lookaheads, precedences, `-v`. The automata
   the same as ocamlyacc's, then the trees.
4. **The programs linked and run by mini-ml**: mini-chidb, mini-cc,
   mini-ml itself, with their generated lexers and parsers; the fixed
   point of decision 7.
5. C output (decision 8), when a C program of ix's world wants it.

After step 4 (the author, 2026-10-02): a `make install` of every mini-
and tiny- program through dune, and mkfiles in ix that build its
components with mini-ml, mini-lex, mini-yacc, mini-cc, mini-asm and
mini-ld, run by mini-mk: ix built by ix. A plan of its own.

## Estimated lines

| part | lines | against |
|---|---:|---|
| mini-lex: reader, regexps to DFA, output | 400 | xix's lex 870 (no `as`, no parameters); ocamllex 3,034 |
| mini-yacc: reader, LR(0), lookaheads, precedences, output, `-v` | 550 | xix's yacc 1,300 (SLR, no precedences); ocamlyacc 6,583 of C |
| `Lexing`, `Parsing` with their engines and the captures | 210 | ocaml-light's 547 of OCaml and 423 of C |
| | 1,160 | |

Guesses, to be replaced by counts in the ledger as each step lands.
`lib_core/parsing/` shrinks by about 340 lines; the runtime's two
stubs go.

## Risks

- **`as` where ocamllex and the second pass disagree** (decision 4):
  found by the token test; the way out is a clause rewritten.
- **A conflict resolved differently** from Berkeley yacc in a corner
  (a rule without terminal against a `%nonassoc` token): the automata
  test finds it state by state.
- **Speed.** The engines are OCaml compiled by mini-ml's simple code
  generator, the tables not compacted: mini-ml lexing and parsing its
  own 600 files is the measure, taken at step 4 before any
  optimization.
- **The kernel** (`kernel/`, built by ocaml-light with its own stdlib):
  none of its files names `Lexing` or `Parsing` (checked), so the new
  modules change nothing for it.

## Open questions for the author

Answered: `Lexing` and `Parsing`; written new; `mini-lex` and
`mini-yacc`; the readers by hand; `generators/`; C later. Still open,
for when C's time comes: ocamllex's and ocamlyacc's syntax around C
actions, or Plan 9's lex and yacc files (decision 8)?
