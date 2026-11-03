\title{datalog}{1}{languages}

# NAME
datalog – facts, and rules run until nothing new is found

# SYNOPSIS
**datalog**
[ **-q** *query* ] ...
[ **-all** ]
[ **-naive** ]
[ **-j** *n* ]
[ **-btree** *name*`/`*arity* ] ...
[ **-s** ]
[ **-profile** ]
*file*`.dl` ...

# DESCRIPTION
*Datalog* reads the *files* in order as one program, runs its rules
until no new fact is found, then answers each query of the files and
each **-q** *query*: the facts that match, sorted. A file's text is
Prolog's without compound terms:

```
edge(a, b). edge(b, c). edge(c, a).
path(X, Y) :- edge(X, Y).
path(X, Y) :- path(X, Z), edge(Z, Y).
?- path(a, X).
```

A rule whose head is in its own body is no loop, as it would be in
\man{prolog}{1}: `path` is found whole, whatever the order of its
rules and of their atoms. `\+ p(...)`, or `not(p(...))`, holds when
no fact matches: a relation is computed whole before another negates
it, and a negation through a recursion is refused. `=`, `\=`, `<`,
`>`, `=<` and `>=` compare two values, numbers then atoms.

**-q** *query*
:    *Query*, as `path(a, X)`, is answered.

**-all**
:    Every fact of every relation that has a rule. With no query and
     no **-all**, nothing is printed.

**-naive**
:    Every rule on every fact at each round, as the definition says,
     and not only on what the round before found.

**-j** *n*
:    *N* domains share a rule's new facts, each the tuples it takes,
     then add what they found, each its share. Where *datalog* was
     built by OCaml 5; elsewhere one runs all.

**-btree** *name*`/`*arity*
:    That relation is kept sorted, in B-trees, as Soufflé keeps them,
     and so are its indexes; the others are hashed. `all`: every
     relation. A relation whose facts a rule tests one after the
     other in order (its indexes give them sorted) is faster sorted;
     one mostly added to, hashed. The facts found are the same.

**-s**
:    The relations' sizes, the rounds, the rules' firings.

**-profile**
:    Each rule's firings, new facts, lookups and seconds, the
     costliest first.

# EXAMPLES
```
datalog graph.dl
datalog -q 'path(a, X)' graph.dl
datalog -profile -btree point_to/2 pointer.dl facts.dl
mini-analyze -facts hello.c > hello.dl
```

# SEE ALSO
\man{analyze}{1}, \man{prolog}{1}, \man{cc}{1}, \man{ml}{1}
