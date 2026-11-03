# The facts: what the compilers tell the analyses

An analysis here is rules over facts, and the rules read like their facts'
vocabulary: this is that vocabulary. Each compiler says a program as Datalog
facts, nothing computed, and the rules in this directory do the rest.

```
 a.c, B.ml --> mini-analyze --> facts --> mini-datalog + rules --> answers
                         |
                 what points where:  Facts (C), Closure_facts (ML)   -facts
                 one function's flow: Ir_facts (C), Ssa_facts (ML)   -flow
```

The examples are `tests/facts_toy/toy.c` and `Toy.ml`; every fact shown is what the
compilers say of them, which `tests/facts_doc.sh` checks in `make test`, with
every relation they can say being in this file. To see them all:

```
mini-analyze -facts lib_code/datalog/tests/facts_toy/toy.c
mini-analyze -facts lib_code/datalog/tests/facts_toy/Toy.ml      (with lib_core's units)
mini-analyze -flow toy.c            mini-analyze -flow Toy.ml
```

## Nothing but symbols and small numbers

Datalog has no compound term, so a place is a name, and a name says what it is:

| a name | C | ML |
|---|---|---|
| a function | `id` | `Toy.inc`, its symbol; `Toy:go/3`, local; `Toy:fun1@29`, a lambda at line 29 |
| a function's next argument | | `Toy.add'`: `let add a b` is `add`, then `add'` |
| a local variable | `main__p` | `Toy:n/1`: name and number, a unit having several `n` |
| a temporary | `main__t3` | `Toy:t2` |
| a global | `gp` | `Toy.pair` |
| a parameter, a result | `id__a`, `ret_id` | `Toy.inc:arg`, `Toy.inc:ret` |
| a call | `_in_main_line_63_1` | `Toy:8:c3`: unit, line, count |
| a field | `_fld__next`, whatever the struct | `fld:fn`, `con:Circle.0`, `tuple:2.0`, `arr:elt` |
| an object | `_malloc_in_cons_line_32`, `_str_in_main_line_65`, `_array_elt_table` | `Toy:block1@10`; a closure is its function's name |
| what the facts do not follow | `_const` | `Toy:const`, `ext`; `exn` what is raised |
| what C returns | | `prim:create_string:block` |
| an external | | `prim:%addint`, `prim:sys_getenv` |

Each expression becomes instructions over variables, a temporary for each value
in between, so a rule never sees a nested expression.

## What points where: C

A statement and what it says. The order of statements is said nowhere: these
analyses are flow-insensitive, and a set of facts is what that means.

**Pointers.** `p = &y; pp = &p; *pp = id(&x); p = *pp;`, in `main`:

```
assign_address('main__t1', 'main__y').
assign('main__p', 'main__t1').
assign_address('main__t2', 'main__p').
assign('main__pp', 'main__t2').
assign_deref('main__pp', 'main__t4').
assign_content('main__t5', 'main__pp').
assign('main__p', 'main__t5').
```

**Arrays**, their elements one place, `table` pointing to it. `p = &table[1];` and
the `table[2]` of `p = table[2] ? p : 0;`. `assign_array_deref(a, q)` is `a[i] = q`:

```
point_to('table', '_array_elt_table').
assign_array_element_address('main__t7', 'table').
assign_array_elt('main__t8', 'table').
```

**Fields.** `n->val = v;`, `p = l->val;`, `pp = &l->val;`:

```
assign_store_field('cons__n', '_fld__val', 'cons__v').
assign_load_field('main__t11', 'main__l', '_fld__val').
assign_field_address('main__t12', 'main__l', '_fld__val').
```

**Objects.** `n = malloc(...)`, `s = "hello"`. `allocator_call` because a call of
an allocator is an object here, not a call:

```
point_to('cons__t1', '_malloc_in_cons_line_32').
allocator_call('malloc', 'cons').
alloc_in('_malloc_in_cons_line_32', 'cons').
point_to('main__t6', '_str_in_main_line_65').
```

**Functions and calls.** `id`, then `*pp = id(&x)`, then `handler = show;
handler(p);`, where `handler` is a global a function's name is assigned to:

```
point_to('id', 'id').
return('id', 'ret_id').
parameter('id', 1, 'id__a').
assign('ret_id', 'id__a').
in_function('_in_main_line_63_1', 'main').
argument('_in_main_line_63_1', 1, 'main__t3').
call_ret('_in_main_line_63_1', 'main__t4').
call_direct('_in_main_line_63_1', 'id').
assign('handler', 'show').
call_indirect('_in_main_line_72_3', 'handler').
```

**What holds no pointer.** A number, arithmetic: the variable `_const`, so that a
value always has something (`scalar`, used by the object-sensitive analyses):

```
scalar('_const').
argument('_in_main_line_68_2', 2, '_const').
```

**Who is where.** `var_in` for each variable a function names; a global too, and
it is `global_var`; `global_def` where its initializer is; `defined` with the
line of the function's first statement; `dead_stmt` for what follows a jump, here
the `n = 0;` after a `return`:

```
var_in('main__p', 'main').
var_in('x', 'main').
global_var('x').
global_def('gp', '_init').
defined('cons', 32).
dead_stmt('cons', 36).
```

## What points where: ML

The same relations, on purpose: a function is a pointer to a function, so
Shivers's question and Andersen's are one (`Closure_facts.mli`). A function takes
one argument, so every call is `call_indirect`, and `add 1 2` is two calls.

**A function.** `let inc n = n + 1`: a place, its parameter, its result. `+` is an
external given all its arguments, so no call: what it does is written in place, a
copy of its own (an addition, a number: `scalar`); it is still named, for
`capabilities.dl`:

```
closure('Toy.inc', 'Toy', '5').
assign_address('Toy:inc/2', 'Toy.inc').
parameter('Toy.inc', 1, 'Toy.inc:arg').
return('Toy.inc', 'Toy.inc:ret').
assign('Toy:n/1', 'Toy.inc:arg').
assign_address('Toy:t1', 'prim:%addint').
scalar('Toy.inc:ret').
```

**A call**, of a function or of an external not given all its arguments (`List.fold_left
(+)`): `let apply f x = f x`, in which function, through what, with what, to where;
`add 1 2` is two calls, the second through what the first returned:

```
in_function('Toy:8:c3', 'Toy.apply\'').
call_indirect('Toy:8:c3', 'Toy:f/6').
argument('Toy:8:c3', 1, 'Toy:x/7').
call_ret('Toy:8:c3', 'Toy.apply\':ret').
```

**Curried.** `let add a b = a + b` is two functions, the first returning the
second. `inner` is for `calls.dl`; `curried` also says it of externals':

```
inner('Toy.add\'', 'Toy.add').
curried('Toy.add\'', 'Toy.add').
assign_address('Toy.add:ret', 'Toy.add\'').
```

**Toplevels.** Where a program starts, and a value's symbol, read from other units:

```
init('Toy:init').
global_var('Toy.inc').
global_def('Toy.inc', 'Toy:init').
assign('Toy.inc', 'Toy:inc/2').
```

**Blocks**, each made where it is written. A record, a tuple, a constructor
applied; `{ fn = f; label = "box" }`, `(inc, 2)`:

```
new_block('Toy.make:ret', 'Toy:block1@10').
alloc_in('Toy:block1@10', 'Toy').
assign_store_field('Toy.make:ret', 'fld:fn', 'Toy:f/9').
assign_store_field('Toy.make:ret', 'fld:label', 'Toy:const').
new_block('Toy:pair/22', 'Toy:block2@21').
assign_store_field('Toy:pair/22', 'tuple:2.0', 'Toy.inc').
```

A pattern and a field read are loads, `Circle r` and `b.fn`:

```
assign_load_field('Toy:r/12', 'Toy:s/11', 'con:Circle.0').
assign_load_field('Toy:first/23', 'Toy.pair', 'tuple:2.0').
assign_load_field('Toy:t17', 'Toy:b/25', 'fld:fn').
```

**Lambdas**, named by where they are:

```
closure('Toy:fun1@29', 'Toy', '29').
assign_address('Toy:t22', 'Toy:fun1@29').
assign('Toy:n/27', 'Toy:fun1@29:arg').
```

**Arrays and exceptions.** An array is an object, its elements one field,
`arr:elt`; `a.(i)` and `a.(i) <- v` a load and a store, by `%array_safe_get` and
`%array_safe_set`, each in place; `Array.make`'s (C's `make_vect`) an object of each call.
What `raise` gives goes to `exn`, where a handler's pattern reads; a variable of
the whole exception (`with e -> raise e`) points to its try's own object instead,
what it caught (for `exceptions.dl`: raised again, what arrived there):

```
new_block('Toy:table/28', 'Toy:block7@34').
assign_store_field('Toy:table/28', 'arr:elt', 'Toy.inc').
assign_load_field('Toy.lookup:ret', 'Toy.table', 'arr:elt').
assign('exn', 'Toy:t45').
new_block('Toy:try2@36:caught', 'Toy:try2@36').
assign('Toy:e/31', 'Toy:try2@36:caught').
```

For `exceptions.dl`, which exceptions may escape: a raise is a call, its site
the call's, with what it raises when written (`raise Not_found`), or a handler's
variable raised again (`with e -> raise e`); an exception made is a block of its
constructor, what a raise of a variable is followed to. A try, in which function
(and in which try, `try_in_try`), each call or raise in it, what its cases catch
for sure (a case with a guard nothing, a variable everything):

```
raise_in('Toy:35:c38', 'Toy.lookup').
raise_of('Toy:35:c38', 'caml_exn_Not_found').
exn_block('Toy:block8@35', 'caml_exn_Not_found').
try_in_function('Toy:try1@16', 'Toy.safe').
in_try('Toy:16:c7', 'Toy:try1@16').
catches('Toy:try1@16', 'caml_exn_Not_found').
catches_all('Toy:try2@36').
reraises('Toy:36:c40', 'Toy:try2@36').
```

**Containers.** A call of `List`'s or `Hashtbl`'s functions given all their
arguments is what the function does, written at the call (`Models`): a loop over
a list two facts, its cells `c = l` then `c = c.tl`, a list made one cell of the
call. A table is one object, made where `Hashtbl.create` is called, its keys and
its values two fields (`tbl:key`, `tbl:val`). The library's own bodies are not
read; one used as a value is the model as a function (`model:List.map`). A call
the model makes, of the function it was given, says so, for `bugs/stack.dl`.
`List.map (fun n -> n * 2) [ ... ]`:

```
assign('Toy:29:c23:m2', 'Toy:t24').
assign_load_field('Toy:29:c23:m2', 'Toy:29:c23:m2', 'con:::.1').
assign_load_field('Toy:29:c23:m1', 'Toy:29:c23:m2', 'con:::.0').
call_indirect('Toy:29:c23:call1', 'Toy:t22').
argument('Toy:29:c23:call1', 1, 'Toy:29:c23:m1').
model_call('Toy:29:c23:call1', 'List.map').
new_block('Toy:t20', 'Toy:29:c23:block').
assign_store_field('Toy:t20', 'con:::.0', 'Toy:29:c23:m3').
```

**What the facts do not follow.** A constant, unit, a constant constructor:
`scalar`, so every value has an object and a variable with none is one no run
reaches. A C function's result is an object of its own, of its call (a call not
given all the arguments: of its name, one for all), its arguments going nowhere (`compare`, `Hashtbl.hash` given anything give nothing back); only
those that keep or call what they are given (`register_named_value`, `ml_signal`,
`thread_new`) and Obj's fields go to `ext`, the one place of what is not followed;
a value made an `Obj.t` (`Obj.repr f`) to `raw`, which nothing reads, a function
there called from where the facts do not go (mini-dotnet's JIT, by its address):

```
scalar('Toy:const').
scalar('Toy.safe:ret').
scalar('ext').
new_block('Toy:counter/24', 'Toy:23:c13:block').
alloc_in('Toy:23:c13:block', 'Toy').
assign_store_field('Toy:counter/24', 'fld:contents', 'Toy:const').
assign_address('Toy:t35', 'prim:sys_getenv').
```

**Types.** The head of a variable's type and of an object's, from `Typing`
(mini-analyze's, `Typing.keep`): a type's constructor, `->` for a function, `*2`
for a pair. The analyses keep an object out of a variable whose type's head is
another (`andersen.dl`'s design note: mini-tiger's Andersen's, past 200 s and
8.5 GB, 5.9 s and 250 MB). None for a type variable or `Obj.t`, nor for a type
with no constructor, field, or built-in name (an abstract `Pervasives.out_channel`,
`Tui_turbo.mli`'s `type model`, inside `Turbo_model.model`: two names for one
type, which would keep apart what is one), and none from
mini-ml's own Closure_facts until 2026-11-02 (`mini-ml -facts`), which did not
keep types:

```
vtype('Toy:n/1', 'int').
vtype('Toy.inc:ret', 'int').
vtype('Toy:table/28', 'array').
vtype('Toy:e/31', 'exn').
htype('Toy:block1@10', 'Toy.box').
htype('Toy.lookup', '->').
htype('prim:create_string:block', 'bytes').
```

And the whole type, where it has no type variable (nor `Obj.t`, nor an object,
whose type is open): two objects of one head are then kept apart too, an
`int list` from a `string list` (`andersen.dl`'s note):

```
vfull('Toy:pair/22', '((int -> int) * int)').
vfull('Toy:t27', 'int list').
hfull('Toy:block2@21', '((int -> int) * int)').
hfull('Toy:block3@29', 'int list').
```

**Capabilities.** `let say (caps : < Cap.stdout; .. >) s = ...`, a parameter that
is one, and what its type names, aliases expanded (`Resolve.capabilities`):

```
takes_cap('Toy.say').
declares('Toy.say', 'stdout').
```

A capability in a record's field is held too: `let greet (e : env) = ...`, `env`
having a field `caps : < Cap.stdout; .. >` (or a record that has one):

```
holds_field('Toy.greet', 'stdout').
```

**Physical equality.** Each `==` and `!=`, in which function; and a side made
in the comparison itself, by what it is, which no other value can be
(`bugs/physeq.dl`). `o == Some 1`, in `is_one`:

```
phys_compare('Toy:43:c43', 'Toy.is_one', '==').
fresh_operand('Toy:43:c43', 'Some').
```

**A call's place**, for `bugs/stack.dl`: a tail call as mini-ml compiles it, its
result the function's and no try around it (`f x` in `apply`); one that would be
but for a try (`try inc n with ...` in `safe`); a call in a handler, which mini-ml
compiles as a function of its own (`retry (n - 1)` in `retry`, line 48). And a type
shaped as a list, a constructor holding one of its own and none two, `chain`,
walked by `size` a call a link:

```
tail('Toy:8:c3').
tail_but_try('Toy:16:c7').
in_handler('Toy:48:c48', 'Toy:try3@48').
tail_but_try('Toy:48:c48').
list_like('Toy.chain').
```

**A case that says nothing**, for `bugs/swallowed.dl`: its answer `()` or a number, so
nothing of what it caught is used, by the exception it names or all. And a
primitive of the runtime that may fail, its external marked `[@@raise Sys_error]`
(`Annotations.raises`), a raise at each call; in `clean`:

```
raise_in('Toy:52:c50', 'Toy.clean').
raise_of('Toy:52:c50', 'caml_exn_Sys_error').
primitive('Toy:52:c50', 'sys_remove').
silent('Toy:try4@52', 'caml_exn_Sys_error').
silent_all('Toy:try4@52').
```

**An external and what it says it raises**, for `bugs/raises.dl`, which checks it
against the C of its primitive (`mini-analyze -bugs runtime.c ... Sys.ml ...`: the C
function is the primitive's name, the exception the global the C raises):

```
external_prim('Toy.remove', 'sys_remove').
declares_raise('sys_remove', 'caml_exn_Sys_error').
```

**Who is where.** As in C. A variable two functions name is what a closure captures:

```
var_in('Toy:n/1', 'Toy.inc').
var_in('Toy.inc:ret', 'Toy.inc').
```

## One function's flow: -flow

Separate facts, of the compiler's own intermediate code, with an order, for
liveness and dominators; they share no name with the above. C's are the stack
code, an instruction a point. `sum`'s loop in `toy.c`:

```
function('sum').
point('sum:1', 'sum').
succ('sum:1', 'sum:2').
def('sum:s/-4', 'sum:1').
use('sum:n/0', 'sum:3').
succ('sum:4', 'sum:13').
succ('sum:4', 'sum:5').
```

`call(P)` says a point is a call, where a register does not survive. A variable is
`function:name/offset`, only those `regs` considers.

ML's are the SSA form, `Ssa_facts`: blocks, a value and the instruction that makes
it one name, `zero` a slot never written. `phi(V, B)` and `phi_arg(V, Pred, X)` are
SSA's: entered from `Pred`, `V` is `X`. `sum` in `Toy.ml`:

```
function('f8_sum<>').
entry('f8_sum<>:b0').
block('f8_sum<>:b0', 'f8_sum<>').
first('f8_sum<>:b0', 'f8_sum<>:v0').
next('f8_sum<>:v0', 'f8_sum<>:v1').
last('f8_sum<>:b0', 'f8_sum<>:t0').
def('f8_sum<>:v4', 'f8_sum<>:v4').
use('f8_sum<>:v1', 'f8_sum<>:v4').
zero('f8_sum<>:v3').
succ('f8_sum<>:b0', 'f8_sum<>:b1').
```

`mini-analyze -dflow` adds what the compiler itself computed, to compare
with: `own_live_out(V, P)`, and for ML `own_live_in(V, B)`, `own_idom(D, B)`.

## Who reads what

| rules | read |
|---|---|
| `pointer.dl` (the author's, 2014) | the `assign*`, `point_to`, `parameter`, `return`, `argument`, `call_*` |
| `points_to/instructions.dl` | the same, into `alloc`, `copy`, `load`, `store`, which the analyses read: `new_block` too |
| `points_to/andersen.dl`, `contexts.dl` | `vtype`, `htype`: what a variable may hold |
| `points_to/contexts.dl` | `var_in`, `global_var`, `in_function`, `init`, `closure`, `curried`, `alloc_in`, `scalar` |
| `calls.dl` | `closure`, `inner`, `in_function`, `init`, over `call_edge` |
| `exceptions.dl` | `raise_in`, `raise_of`, `reraises`, `exn_block`, the `try`'s, `catches*`, over `call_edge`, `pt`, `reached` |
| `dead.dl` | `defined`, `closure`, `global_def`, `dead_stmt`, `allocator_call` |
| `capabilities.dl`, `capabilities_types.dl` | `takes_cap`, `declares`, `assign_address`, `global_def` |
| `bugs/pointers.dl` | `call_direct`, `return`, and `heap`, `local`, `literal`, which mini-analyze makes of the names |
| `bugs/physeq.dl` | `phys_compare`, `fresh_operand` |
| `bugs/stack.dl` | `tail`, `model_call`, `tail_but_try`, `in_handler`, `in_try`, `list_like`, `parameter`, `vtype`, `inner`, `alloc_in`, over `target` and `reach` |
| `bugs/raises.dl` | ML's `external_prim`, `declares_raise`; C's `call_direct`, `argument`, `parameter`, `in_function`, `global_var`, `defined` |
| `bugs/swallowed.dl` | `silent`, `silent_all`, `catches`, `primitive`, `curried`, over `exceptions.dl`'s `arrives` |
| `liveness.dl` | C's `-flow` |
| `liveness_ssa.dl`, `dominators.dl` | ML's `-flow` |

Not said by a compiler: `heap(L)`, `local(L, F)`, `literal(L)` (mini-analyze, of C's
names) and `own_unit(U)`, `own_init(I)` (mini-analyze -caps: the program's units,
not the library's).

## What the rules then say

`handler(p)`, a call through a pointer, in `toy.c`: nothing says what it reaches,
and `target` is found (`contexts.dl`, `insensitive.dl`):

```
target('_in_main_line_72_3',show).
```

The chain, each a rule over the facts above: `assign('handler', 'show')` copies what
`show` points to, `point_to('show', 'show')`, so `handler` points to `show`, a
function, since `return('show', 'ret_show')`.
