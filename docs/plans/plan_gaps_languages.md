# Plan: the gaps in languages/, the big ideas of programming languages ix does not teach yet

The author (2026-10-30): "I feel that for languages/ and from a
teaching perspective we have great coverage of the history of CS for
languages, compilers, etc. [...] Anything big missing?", then "we
can't cover everything of course, but we should aim really for the
big milestones in CS and big ideas".

**Status: a survey, nothing built.** A list to choose from, as
[plan_gaps.md](plan_gaps.md) is for the rest of ix: each gap, when
taken, gets a plan of its own or a stage in an existing one. No line
counts are estimated here.

## The measure

A candidate has to teach an idea that no program in ix teaches. A
famous language whose idea is already taught elsewhere stays out.

## What ix already teaches

| where | the idea |
|---|---|
| `languages/c/` | a classic compiler to the machine's code, SSA |
| `languages/pascal/` | one pass to a portable code, P-code |
| `languages/smalltalk/` | a bytecode VM with its image |
| `languages/scheme/` | abstract machines, CESK and SECD; call/cc, tail calls |
| `languages/prolog/` | unification, backtracking, Warren's machine |
| `languages/datalog/` | rules run bottom up to their fixpoint |
| `languages/forth/` | threaded code |
| `languages/ml/` | a functional language, native: closures, Hindley-Milner, SSA, a generational collector |
| `languages/dotnet/`, `tiger/` | a typed, self-describing VM, a verifier, a JIT that knows the types |
| `browsers/javascript/` | an interpreter on trees, quickening, closures |
| `database/sql/` | a declarative query language |
| `utilities/text/awk`, `shell/` | the scripting languages |
| `kernels/oberon/`, `kernels/singularity/` | a language as a system's protection, ownership checked at run time |

## The big gaps, in order

### 1. Lazy evaluation: Miranda, Haskell

Everything in `languages/` is call-by-value, so nothing teaches
call-by-need, purity, or graph reduction: Turner's SASL and combinators
(1976-79), the G-machine (Johnsson and Augustsson, 1984), the STG
machine (Peyton Jones, 1992). Type classes come with it (Wadler and
Blott, 1989), compiled by passing dictionaries: a major idea of type
systems that ML does not have. Beside `ml/`, a reader sees the two ways
of compiling a functional language.

The idea furthest from everything ix has: the first choice if only one
is taken.

### 2. The speculating JIT: Smalltalk, Self, V8

mini-dotnet's JIT knows the types from the metadata; this one guesses
them at run time and is ready to be wrong. Inline caches (Deutsch and
Schiffman, 1984, for Smalltalk-80), polymorphic ones and deoptimization
(Self, around 1991-92), hidden classes (V8, 2008): the idea behind
today's fast dynamic languages.

JavaScript is the place, as it needs all three; plan_gaps.md's
"Browsers" already lists its bytecode VM with inline caches, possibly
after plan_dotnet.md's JIT.

### 3. Concurrency as the language: Erlang

No language in `languages/` is built around concurrency;
Singularity's channels are the nearest, at the kernel's level. Erlang
and its BEAM teach cheap processes preempted by counting reductions, a
heap per process, messages, and "let it crash" with supervisors.

Limbo or Newsqueak would be the Plan 9 lineage, closer to principia and
leading to Go (Hoare's CSP behind them). Erlang is preferred: its
lessons differ more from what ix has.

### 4. Proofs as programs: LCF, HOL Light

ML was invented as the meta-language of LCF (Milner, 1970s), so ix has
the language without the reason it exists. An abstract type `thm` that
only a small trusted kernel can build is the whole idea, and the type
checker is what enforces it. HOL Light's kernel is a few hundred lines
of OCaml (from memory, to check), so this is likely the most idea per
line here. It opens Curry-Howard, and reuses the unification whose
story `languages/ml/Typing.mli` already tells.

The cheap one to take alongside the first.

### 5. Ownership checked by a compiler: Rust

Linear ownership is taught already, in `kernels/singularity/`'s
`Exchange`, but its README says what is lost: Sing# checks it when a
program is compiled, and ix's runs check it (a block used after it was
sent raises `Not_held`). Rust (2015) made the compile-time rule its
whole memory model. What is missing is the checker, the borrow part
above all: a small language with one, or `mini-singml` given one.

## Smaller, inside what exists or cheap

- **Lisp's macros**: code as data is Lisp's defining idea (McCarthy,
  1960), hygiene the later one (Kohlbecker, 1986). `define-syntax` under
  `languages/scheme/` is only in the highlighter, so this extends
  mini-scheme and needs no new language.
- **Array languages, APL** (Iverson, 1962): the notation and whole-array
  thinking are a distinct idea, and the implementation is tiny.
- **BASIC** (Kemeny and Kurtz, 1964): a social milestone more than an
  idea, Dartmouth's time-sharing and then the micros. Cheap, and at home
  beside mini-dos.

## Left out

- **Fortran**: optimizing compilers, taught by the SSA of `c/` and `ml/`.
- **Algol**: Pascal descends from it.
- **Simula**: classes, taught by Smalltalk and C#.
- **COBOL**: no comparable implementation idea to teach.
- **Tcl, Lua, Python, Ruby**: more dynamic languages' VMs; JavaScript
  and Smalltalk teach them.

## Status

2026-10-30: survey written. Nothing built.
