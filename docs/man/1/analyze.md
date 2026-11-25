\title{analyze}{1}{devtools}

# NAME
analyze – what C and ML programs may do, by facts and Datalog rules

# SYNOPSIS
**mini-analyze**
[ **-dead** | **-caps** | **-exn** | **-bugs** ]
[ **-facts** | **-flow** | **-flow-answers** ]
[ **-r** *rules* ]
[ **-L** *lib* ]
[ **-I** *dir* ] ...
[ **-own** *dir* ] ...
[ **-D** *name*`=`*value* ] ...
[ **-root** *f* ] ...
[ **-start** *units* ]
[ **-context** *file* ]
[ **-library** ]
[ **-summary** *file* [ **-program** *name* ] ]
[ **-alone** ]
[ **-no-models** ]
[ **-fingerprint** ]
[ **-sources** *dir* ]
[ **-v** | **-debug** | **-quiet** ]
*program*`.exe` ... | *program*`.manifest` ... | *dir* ... |
*file*`.c` ... | *file*`.ml` ...

# DESCRIPTION
*Analyze* reads the *files* as one program, by mini-cc's front end
for C and mini-ml's for ML, writes what each says as Datalog facts,
and runs on them the rules of `analyzers/datalog`, with
\man{datalog}{1}'s engine: what a pointer may point to, by Andersen's
analysis, then the question asked of it. Each answer is a "may": what
the facts cannot see is taken as able to do anything, so what is said
of a program holds of every run, and what is said may never happen.

With no option, each call through a pointer (C) or through a variable
(ML: a closure is a pointer to a function) is said with the functions
it may reach, and for C the bugs the same answers show (`bugs/pointers.dl`): a
`free` of what is not the heap's, a local's address returned. An ML
program's library, lib_core's units it names, is read with it.

An ML program is best given by its build, which knows its files: an
*`.exe`* dune builds (`tiny/TinyShell.exe`, or `_build/default`'s),
whose link mini-analyze asks dune for (`dune describe`, `dune rules`,
in a build directory of its own: `analyzers/ml/Dune_manifest.ml`); a
*`.manifest`*, what tiny-ld **-map** writes beside the program it
links, each unit and its source (t-IX's build writes one for each
program, `tiny/TinyKernel/_make/src/temp.manifest`); a directory, the
manifests under it, or with none the executables dune builds under it,
those of tests' directories left out. The program is then read as
linked, its platform's files among them, and nothing is told by
**-L**, **-I** or **-own**: its own files are those given to the
linker, its library's units are reported on when they are of the
program's part of the project (`tiny/`'s `TinyLib*.ml`), and **-dead**
of one program reports on its own components, the files no other
program of the build links. Several programs, or a directory of them,
are each run and merged: **-dead** keeps what every program that has
the file says (`dead_all.dl`), the others every program's reports
(`said_all.dl`). A library's file and programs, manifests or `.exe`,
`mini-analyze -dead tiny/TinyLibGUI.ml tiny/TinyKernel/_make/src/*.manifest`,
say its dead code over those that link it; the file alone, over the
programs whose files name it (`analyzers/ml/Caller_finder.ml`). Without a build, the
*files* given are the program (**-L**, **-I**, **-own** below).

**-dead**
:    What no run can reach, from `main` and the toplevels (`dead.dl`):
     functions, and why (nothing names it, named only by dead code, a
     pointer taken and never called), globals, fields stored and never
     read, constructors matched and never built, C statements after a
     jump.

**-caps**
:    Whether ML's own functions hold the capabilities they need
     (`capabilities.dl`): held, from a parameter's type
     `< Cap.stdout; .. >` or a record's field; needed, from what the
     function reaches. Said: no capability, not the right one, one it
     may not need.

**-exn**
:    The exceptions an ML program's toplevels may let escape
     (`exceptions.dl`), with where they may be raised; those a
     function C calls may let go back to C (`Callback.register`'s, a
     signal's handler); those reaching a `try` that catches all and
     raises from its handler (the kernel's `guard`, a panic).

**-bugs**
:    An ML program's bugs that may be, each line named by its
     analysis (`docs/plans/done/plan_bug_analyses.md`): `physeq`, an `==`
     or `!=` with a side made in the comparison (`bugs/physeq.dl`), whose
     answer is known before it runs, or comparing a value kept (a
     cache's last) of a type the function does not know with one
     changed in place; `stack`, a recursion the stack
     may not hold (`bugs/stack.dl`): a function calling itself back in a
     `try`, its result the function's, which mini-ml makes no tail
     call, or not by a tail call over a list, a frame an element;
     `swallowed`, an error of the system (`Unix_error`, `Sys_error`)
     that may arrive at a `try` whose case answers a constant, saying
     nothing (`bugs/swallowed.dl`, over `exceptions.dl`); `crash`, a
     program's own exception that may reach a `try` catching all whose
     handler raises another (`exceptions.dl`'s `ends_in`); `int31`, a
     literal or a shift that an int of the Pi 1, 31 bits, does not hold,
     a line a function (`bugs/intwidth.dl`): not in a directory meant
     for 64 bits only (`wide_dir`), nor reached only under an
     `if Sys.int_size >= 63`; `order`, a `Hashtbl.iter` or `fold`
     whose order reaches an output: a write in its closure, in a walk
     of a list made in that order, or `Marshal` given one
     (`bugs/order.dl`; `List.sort` makes a list in no table's order);
     `sharing`, a `Marshal` without `No_sharing`, its bytes depending
     on what the compiler shared; `init`, a unit's start reading a
     global of a unit that starts after it, in `-start`'s order;
     `link`, two files of one unit's name, each named by units of its
     directory (`bugs/init.dl`); `race`, a field written by what a
     signal's handler runs and by the program, of an object the
     program made, a bool being a flag (threads not yet); `wait`, a
     `Condition.wait` not in a `while` (`bugs/races.dl`); `leak`, a
     channel or a lock taken and given back in one function, but not
     when a call on a path between raises (`bugs/pairs.dl`, over the
     program's functions in mini-ml's SSA form), across a call of a
     helper that closes its argument or returns what it opens; `unused`, a local
     variable never read, its name not `_x`: OCaml's warnings 26 and
     27 by rules (`bugs/unused.dl`), for what no compiler checks (the
     kernel's ML); `layout`, a statement in the column of an `if`'s
     branch above it, which OCaml runs whatever the test
     (`bugs/layout.dl`, over the program's tree as facts); `evalorder`,
     two operands that both have an effect, a write or I/O, in an
     application, a tuple, a record, whose order the compiler chooses
     (`bugs/evalorder.dl`: OCaml right to left, mini-ml -dotnet left to
     right). C files: the
     report without an option, its `bug?` lines `bugs/pointers.dl`'s.
     C files and ML ones (mini-ml's runtime and lib_core: what
     `analyzers/datalog/tests/raises.sh` gives): each external's
     `[@@raise E]` against what the C of its primitive raises,
     `raises` (`bugs/raises.dl`), one analysis over two languages.

**-facts**
:    The facts, not the analysis: to write one's own rules
     (`analyzers/datalog/FACTS.md` says each relation).

**-flow**
:    Each function's code as facts: ML's in SSA form, for
     `liveness_ssa.dl` and `dominators.dl`; C's as mini-cc's stack
     code, for `liveness.dl`. **-flow-answers**: the compilers' own
     answers on those facts, their liveness and dominators, as facts:
     what the rules must find (the tests compare them).

**-sources** *dir*
:    Where a manifest's paths are read, the build having run in a copy
     of *dir* (t-IX's, in `tiny/TinyKernel/_make/src` of `tiny`); the
     reports then name *dir*'s files; without it, a manifest's paths
     are read in its directory.

**-r** *rules*
:    The directory of the `.dl` files and `points_to/`; by default
     `analyzers/datalog` of the current directory.

**-L** *lib*
:    The standard library's directory. Without **-L**, the one nearest
     the first ML *file* in the project, then the shallowest:
     `tiny/TinyLibCore` for `tiny/`'s programs, `lib_core` for the rest
     of ix (a directory with a `Stdlib`, or the one above it with a
     `units.txt`); outside a project, `lib_core`. For lib_core,
     *lib*`/stdlib`'s Stdlib must be there. Without its `units.txt`
     (run elsewhere than ix's root), a warning, and an ML program's units find no
     Stdlib. Or a library in one directory, its own `Stdlib.mli` there
     and no `units.txt`: t-IX's `tiny/TinyLibCore`, read as tiny-ml
     reads it. Its units are looked up before the **-I**'s; what tiny-ml
     takes for granted (`ref`, `option`, `result`, `&&`, the `Printf`
     calls it expands, `int32`) is declared as lib_core declares it; its
     `Stdlib.ml`'s own `Failure`, `Not_found`... are the predefined ones;
     no mlpp, `[@@deriving]` left out; its primitives' names (`%ref`,
     `ml_array_get`...) known as mini-ml's.

**-I**, **-D**
:    As \man{cc}{1}'s. For ML, an **-I** directory's units that the
     program names are read with it, but as a library: nothing is said
     of them.

**-own** *dir*
:    ML: the units that the program names and that are found in *dir*
     are its own, reported on as the *files* given are. The units of
     every directory are looked up in the order given, after the
     directories of the *files*, whose units are the program's own
     too unless their directory is an **-I**'s.

     A unit in none of these directories, the **-I**'s and the
     library's is looked for in the project, the first directory above
     the first *file* with a `dune-project`
     (`analyzers/ml/Unit_finder.ml`). Where several directories have a
     file of its name, the program as a whole decides: a directory
     already chosen for it, then the one with the most of the units
     its files name, then the nearest; a directory with its own
     `Stdlib` is another platform's library and never chosen. A unit
     the build makes, from a `.mll` or `.mly` of its name in a
     directory of the *files* (`Lexer.mll`, `Parser.mly`), is taken
     from dune's build directory, the project's `_build/default`
     (`make generated` makes them alone), and never from another
     directory of the project; not built, a warning says so.
     A unit found in the first *file*'s top directory of the project is the
     program's own (`tiny/` for `tiny/TinyBuildSystem.ml`), one found
     elsewhere a library's (`lib_crypto`). A program can so be given
     by its main file alone, `mini-analyze -dead tiny/TinyBuildSystem.ml`;
     an interface whose implementations are elsewhere
     (`tiny/TinyLibSystem.mli`) is read as one without code, and
     **-own** chooses a platform's (`tiny/TinyLibSystem/unix`,
     `tinykernel`). **-v** says each choice, the library's and a unit's
     with its candidates and their scores, and where each file read
     comes from (given, **-own**, the program's directory, **-L** or
     **-I**, found in the project), a unit read by its interface alone,
     and a tie as a warning. A
     library's functions that
     this one program does not call are said dead too (by its build,
     its components alone: above). For one
     file of a program, give it and the main file, the libraries by
     **-I**; for a t-IX program as tiny-kernel runs it:
     `mini-analyze -dead -L tiny/TinyLibCore -I tiny/TinyLibSystem/tinykernel tiny/user/temp.ml tiny/TinyAppTemperature.ml`
     says only what is dead in `temp.ml` and `TinyAppTemperature.ml`.
     **-v** says each file read: `reading` for the program's own,
     `the library's` for the others.

**-root** *f*
:    *F* is entered from where the facts do not go: assembly, a
     kernel's trap.

**-start** *"units"*
:    The units in the order they start, as **mini-ml -start** is given
     them (mkprog's: the stdlib's, the libraries', the program's), for
     **-bugs**' `init`. Without it, only the library's units start
     before the files'.

**-context** *file*
:    The context file of `points_to/`: `call1_heap1` for C,
     `call1_rec` for **-exn**, `insensitive` for **-bugs**. The
     sharper, the longer.

**-library**
:    Every function may be called from outside, not `main` alone.

**-summary** *file* [ **-program** *name* ]
:    With **-dead**: the program's files and reports also as facts, in
     *file*. They say which files the program reads (`has`) and which it
     reports on (`own`), and give an implementation whose interface is
     elsewhere (`implements`), a file outside the project (`outside`:
     no `dune-project` above it), and each report (`report`). *Name*
     (the first file's if not given) tells the programs apart.
     `analyzers/datalog/dead_all.dl` merges several programs' facts:
     a report is kept where every program that has the file, or another
     implementation of its interface, says it. Several programs given
     are merged so by mini-analyze itself; `ix_check.sh`'s, given by
     their files, are merged so:

         mini-analyze -dead -summary a.dl -program a ... a.ml
         mini-analyze -dead -summary b.dl -program b ... b.ml
         mini-datalog analyzers/datalog/dead_all.dl a.dl b.dl

**-alone**
:    ML: the files' own facts, not their library units'.

**-no-models**
:    ML: `List`'s, `Hashtbl`'s and `@`'s code read as written, not
     their models at each call (`analyzers/ml/Models.ml`), which are
     3 to 5 times faster on mini-cc and mini-ml: to compare.

**-fingerprint**
:    After the report, one number of every answer: two runs of the
     analysis, native or on .NET, agree if their numbers do.

**-v**, **-debug**, **-quiet**
:    As every ix program's (\man{common}{1}). **-v** says each rules
     file read, the summaries, the program's files and the library's
     units, and the evaluation (by \man{datalog}{1}'s engine, in this
     process): its rules and facts, then its rounds and tuples
     derived; **-debug** also each relation's size.

# EXAMPLES
In ix's root, `bin/` first on the path; elsewhere **-r** and **-L**
say where ix is (`IX`), for files given without their build. Each report's last line, its counts, is left
out here, and long lines are cut. The files are in
`analyzers/examples/`, and its `run.sh` runs these commands against
the reports in full (`expected.out`).

A C program, `calc.c`: a table of operations, one called by pointer.

```
void	*malloc(unsigned long);
void	free(void*);

typedef struct Op Op;
struct Op { char *name; int (*run)(int); };

int	twice(int x) { return 2*x; }
int	square(int x) { return x*x; }
int	negate(int x) { return -x; }

Op	ops[] = { { "twice", twice }, { "square", square } };

int
apply(Op *o, int x)
{
	return o->run(x);
}

int
main(void)
{
	char *s = "done";

	apply(&ops[1], 3);
	free(s);
	return 0;
}
```

```
% mini-analyze -r $IX/analyzers/datalog calc.c
calc.c:16: in apply, through o->run: square, twice
bug? calc.c:25: in main, free may be given a string (line 22),
  not the heap's
% mini-analyze -r $IX/analyzers/datalog -dead calc.c
dead field: name stored in _init, nothing live reads it
calc.c:9: dead: negate, nothing names it
```

`o->run` may reach `twice` too, though `ops[1]` alone is passed: an
array is one object to the analysis, its elements one field.

An ML program, `Log.ml`:

```
let say (caps : < Cap.stdout; .. >) s = Console.print caps s
let shout s = print_string (String.uppercase_ascii s)
let unused () = shout "never"
```

and `Main.ml`:

```
exception Empty

let first l = match l with [] -> raise Empty | x :: _ -> x

let handlers =
  [ (fun caps -> Log.say caps "hello\n");
    (fun _ -> Log.shout "bye\n") ]

let () =
  Cap.main (fun caps ->
    List.iter (fun h -> h caps) handlers;
    ignore (first []))
```

The program built by dune (`analyzers/examples/dune`: `Log` and `Main`, on
lib_core), given by its executable, in ix's root:

```
% mini-analyze analyzers/examples/Main.exe
analyzers/examples/Main.ml:11: in Main:fun at line 11, through h:
  Main:fun at line 6, Main:fun at line 7
never reached: Log.unused (analyzers/examples/Log.ml:3)
% mini-analyze -dead analyzers/examples/Main.exe
analyzers/examples/Log.ml:3: dead: Log.unused, nothing names it
% mini-analyze -caps analyzers/examples/Main.exe
analyzers/examples/Log.ml:2: Log.shout: no capability, needs
  Cap.stdout (Stdlib.print_string)
% mini-analyze -exn analyzers/examples/Main.exe
Main.ml: the toplevel may let Main.Empty escape, raised at Main.ml:3
  (Main.first)
Main.ml: the toplevel may let Invalid_argument escape, raised at
  String.ml:153 (String.map)
```

Or without a build, anywhere, by its files, the library by **-L**:

```
% mini-analyze -r $IX/analyzers/datalog -L $IX/lib_core Log.ml Main.ml
Main.ml:11: in Main:fun at line 11, through h: Main:fun at line 6,
  Main:fun at line 7
never reached: Log.unused (Log.ml:3)
% mini-analyze ... -dead Log.ml Main.ml
Log.ml:3: dead: Log.unused, nothing names it
```

`Invalid_argument` is lib_core's: `Log.shout`'s `String.uppercase_ascii`
is a `String.map`, whose new string's primitive may refuse its length
(its `[@@raise]`). Each line names the raises on its own toplevel's way
out, not those of the library's other units.

A t-IX program, by the manifest its build wrote (tiny-ld **-map**),
its paths read in `tiny/`, which the build copied:

```
% make -C tiny/TinyKernel
% mini-analyze -dead -sources tiny tiny/TinyKernel/_make/src/build.manifest
```

says what is dead in `TinyBuildSystem.ml`, the one file no other
program links; `mini-analyze -dead -sources tiny tiny/TinyKernel/_make/src tiny`,
every t-IX program and every one dune builds under `tiny/`, merged
(`analyzers/datalog/tests/tiny_check.sh`).

One of ix's programs, all its units, in ix's root (a second):

```
% mini-analyze -dead utilities/calc/dc/*.ml
utilities/calc/dc/Dc.ml:116: dead: Dc.of_string, in init but no call
  goes through the pointer
utilities/calc/dc/Dc.ml:627: dead: Dc.feed, nothing names it
utilities/calc/dc/Num.ml:64: dead: Num.sub, nothing names it
```

`Num.sub` is called by nothing in ix. `Dc.feed` and `Dc.of_string`
are dead in mini-dc, not in mini-bc, which links `Dc` and calls
`feed`: **-dead** is of one program. `analyzers/datalog/tests/sweep.sh` runs a
mode on each of ix's programs, `triage.sh` sorts what **-dead** says.

One's own question: the facts, and rules over them. Which functions
may `main` reach, calls through pointers too (`target`, of
`points_to/`)? In `graph.dl`:

```
calls(G, F) :- in_function(I, G), call_direct(I, F).
calls(G, F) :- in_function(I, G), target(I, F).
reaches(G, F) :- calls(G, F).
reaches(G, F) :- reaches(G, H), calls(H, F).
```

```
% mini-analyze -facts calc.c > calc.dl
% P=$IX/analyzers/datalog/points_to
% mini-datalog -q 'reaches(main, F)' \
    $P/instructions.dl $P/contexts.dl $P/insensitive.dl \
    calc.dl graph.dl 2> /dev/null
reaches(main,apply).
reaches(main,free).
reaches(main,square).
reaches(main,twice).
```

The facts of the code: what is live across a call, which a compiler
must save (`s`, the string `free` is given after `apply`):

```
% mini-analyze -flow calc.c > flow.dl
% mini-datalog -q 'across_call(V, P)' \
    $IX/analyzers/datalog/liveness.dl flow.dl
across_call('main:s/-8','main:7').
```

# FILES
`analyzers/datalog/*.dl`
:    The questions: `bugs/pointers.dl`, `calls.dl`, `dead.dl`,
     `capabilities.dl`, `exceptions.dl`, `liveness.dl`, ...; each
     file's header says what it reports, why so, and its history.

`analyzers/datalog/points_to/`
:    The pointer analysis: `instructions.dl`, `contexts.dl`, and the
     context files.

`analyzers/datalog/FACTS.md`
:    Each relation, with the facts of a small program.

`analyzers/datalog/README.md`
:    The analyses run on ix, what they found, their costs.

`analyzers/examples/`
:    The programs of EXAMPLES, and `run.sh`, which checks their
     reports.

# SEE ALSO
\man{datalog}{1}, \man{cc}{1}, \man{ml}{1}, \man{dotnet}{1},
\man{common}{1}

# BUGS
Built by dune only, not by ix. A C function of the same name in two
files is one function. A capability is held by its type alone: a
`< .. >`, or a parameter named `caps` of no written type, holds none
that can be named. `Unix.openfile`'s flags are not read, so it needs
`Cap.open_in` or `Cap.open_out`. A manifest's C programs (tiny-cc's)
are not read. **-exn** on mini-cc or mini-ml takes
a minute and 4 to 6 GB.
