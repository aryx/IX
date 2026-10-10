# languages/prolog: mini-prolog

Prolog, written here (nothing copied: the author's playground has no
Prolog): Edinburgh's syntax, the core of the ISO standard, integers
only. The plan: [`plan_prolog.md`](../../docs/plans/done/plan_prolog.md).

| module | what |
|---|---|
| `Prolog` | a term (an atom, an integer, a variable, a compound term), the operators' table, a term written (`write`, `writeq`), the standard order |
| `Prolog_read` | a text's clauses, each read by the operators' priorities as they are then: by hand, since `op/3` changes the grammar while the text is read |
| `Prolog_db` | a predicate's clauses as they are kept: the variables numbered, so a call fills an array and copies the body |
| `Prolog_machine` | unification and its trail; the goals to prove and the choice points, both data; the cut; `catch` and `throw`; the tracer's four ports |
| `Prolog_builtins` | the predicates with one answer, in OCaml: comparison, `functor`, `=..`, `is`, the atoms', `sort`, `assert`, `op`, `write`, `format`, `read`, `consult`, `listing` |
| `Prolog_prelude` | what is written in Prolog: `append`, `member`, `length`, `between`, `clause`, `retract`, `bagof`, `setof`, `maplist`, the grammars' `-->` |
| `Wam` | the second machine's instructions: Warren's `get`, `put`, `unify`, `call`, `try`, `retry`, `trust`, `switch_on_term` |
| `Wam_compile` | a clause compiled to them: which variables are permanent, a structure's two modes, the index on the first argument; the listing |
| `Wam_machine` | those instructions run: the argument registers, the environments, the choice points; `call/N`, `catch/3`, `findall/3` |
| `CLI`, `Main` | the command: files consulted, `-g goal`, a prompt, `-trace`, `-wam`, `-S` |

`mini-prolog -h` says how, by examples.

On mini-9pi's card it is `prolog`, with `/lib/prolog/classics.pl`
(`kernels/9pi`'s `make check-prolog`: a recorded session, both
machines).

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

It is not the WAM: a clause is a term, not instructions.

## The second machine: the WAM

`-wam` runs the same programs by Warren's abstract machine (1983),
what Prolog is known by among those who write compilers as Pascal is
by its P-code (mini-pascal) and Smalltalk by its bytecode
(mini-squeak). A clause is compiled; `-S` shows the code:

    $ mini-prolog -S tests/code.pl
    app/3:
        switch_on_term A1
            a variable: L1|L2
            .(...): L2
            []: L1
            another: fail
    L1:
        get_constant [], A1
        get_variable X4, A2
        get_value X4, A3
        proceed
    L2:
        get_list A1
        unify_variable X4
        unify_variable X5
        get_variable X6, A2
        get_list A3
        unify_value X4
        unify_variable X7
        put_value X5, A1
        put_value X6, A2
        put_value X7, A3
        execute app/3

- The head is `get` instructions against the argument registers, a
  goal is `put` instructions and a `call`; the last goal is `execute`,
  a jump. A structure's arguments are `unify` instructions in one of
  two modes: read when the structure is there, write when a variable
  is and the structure is built for it. So `app`'s second clause both
  takes a list apart and makes one, by the same code.
- A variable that lives across a call is permanent (`Yn`, in an
  environment that `allocate` makes); the others are registers.
- A predicate is an index over its clauses: a switch on what the
  first argument is, then `try`, `retry`, `trust` over those that may
  match. A call with one candidate leaves no choice point.
- A disjunction, an if-then-else and a negation are a predicate of
  their own (`'$aux'`), their cut the clause's by `get_level` and
  `cut`.

What is the first machine's and stays it: the terms (OCaml's heap,
not the machine's own cells: `Wam`'s header says what follows from
it), the trail, the built-ins, the reader, the database. A predicate
is compiled when it is first called, and its index made again when
its clauses have changed. No tracer: `-trace` is the first machine's.
One difference seen by a program: a call that is running keeps the
index it started with, so a clause retracted meanwhile is still tried
by it (the standard's logical update view), where the first machine
does not try it.

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
  tracer, the prompt, a file with mistakes, the control constructs
  and the database (`control.pl`), the WAM's code (`code.pl`); then
  the same but the tracer by `-wam`, against the same outputs. No other Prolog is on the
  author's machine: the `.out` files were read, not made by one.

## Its speed

Naive reverse of 30 elements, 2,000 times (992,000 inferences): 0.85 s
by OCaml's build, 2.9 s by mini-ml's (arm64, 2026-10-09), in 6 MB.

The two machines (`tests/bench.sh`, 2026-10-10, arm64): naive reverse
of 30 elements 20,000 times, in thousands of inferences a second, and
the eight queens' 92 answers by permutations.

| build | machine | nrev30, K LIPS | queens(8), all |
|---|---|---|---|
| OCaml's | first | 1,657 | 1.13 s |
| OCaml's | `-wam` | 2,876 | 0.45 s |
| mini-ml's | first | 472 | 3.11 s |
| mini-ml's | `-wam` | 521 | 2.11 s |

The WAM is 1.7 and 2.5 times faster by OCaml's build, 1.1 and 1.5 by
mini-ml's (why less there: not looked at). Its registers are not
allocated as Warren's (an argument is always moved to a register of
its own, `app`'s `L` above), and a structure in write mode is a list
reversed.
