# languages/prolog: mini-prolog

Prolog, written here (nothing copied: the author's playground has no
Prolog): Edinburgh's syntax, the core of the ISO standard, integers
only. The plan: [`plan_prolog.md`](../../docs/plans/plan_prolog.md).

| module | what |
|---|---|
| `Prolog` | a term (an atom, an integer, a variable, a compound term), the operators' table, a term written (`write`, `writeq`), the standard order |
| `Prolog_read` | a text's clauses, each read by the operators' priorities as they are then: by hand, since `op/3` changes the grammar while the text is read |
| `Prolog_db` | a predicate's clauses as they are kept: the variables numbered, so a call fills an array and copies the body |
| `Prolog_machine` | unification and its trail; the goals to prove and the choice points, both data; the cut; `catch` and `throw`; the tracer's four ports |
| `Prolog_builtins` | the predicates with one answer, in OCaml: comparison, `functor`, `=..`, `is`, the atoms', `sort`, `assert`, `op`, `write`, `format`, `read`, `consult`, `listing` |
| `Prolog_prelude` | what is written in Prolog: `append`, `member`, `length`, `between`, `clause`, `retract`, `bagof`, `setof`, `maplist`, the grammars' `-->` |
| `CLI`, `Main` | the command: files consulted, `-g goal`, a prompt, `-trace` |

`mini-prolog -h` says how, by examples.

## The machine

A goal is proved by trying its predicate's clauses in order. What is
left to prove (the continuation) and what is left to try (the choice
points) are OCaml values, not OCaml's stack: a recursion of 20,000
calls that is not a tail call is a list of 20,000 frames in the heap.

- A continuation's goal carries the height of the choice points its
  cut cuts back to. `( C -> T ; E )`, `\+`, `call/N`, `findall/3` and
  `catch/3` are that: a choice point pushed, a goal with its own
  height, a frame that cuts.
- A binding is put on the trail only if the variable is older than the
  last choice point: a program that leaves none (a loop, naive
  reverse) keeps no trail.
- A clause that cannot match the call's first argument (another atom,
  another functor) is not tried and leaves no choice point: `append`
  on a list that is known is deterministic.
- `throw` looks in the continuation for the `catch/3` it is still
  inside; a catch whose goal has ended is not there.

It is not the WAM: a clause is a term, not instructions
(plan_prolog.md, decision 2; the WAM would be a second machine, under
a flag).

## What is not there

Floats (`/` is `//`); modules; strings (a text between double quotes
is the list of its codes); the occurs check
(`unify_with_occurs_check/2` does it); streams (`write/1` and `read/1`
only: the terminal); a garbage collector of its own; tabling;
`assert`'s logical update view (a clause retracted is not tried by a
call already running); `bagof/3` grouping variant keys (they must be
identical).

## Tests

- `tests/Test.exe` (Testo, dune's build): the reader and the printer,
  a goal's answers, an error's term.
- `tests/run.sh`: by text, on dune's build and on mini-ml's (`-5`: arm
  under mini-5i, six minutes): the classical programs
  (`classics.pl`), 197 checks of the language (`language.pl`), the
  tracer, the prompt, a file with mistakes. No other Prolog is on the
  author's machine: the `.out` files were read, not made by one.

## Its speed

Naive reverse of 30 elements, 2,000 times (992,000 inferences): 0.85 s
by OCaml's build, 2.9 s by mini-ml's (arm64, 2026-10-09), in 6 MB.
