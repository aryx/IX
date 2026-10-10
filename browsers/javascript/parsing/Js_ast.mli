(* Js_ast: a JavaScript program as a tree -- the parser's output
   (Js_parse), the interpreter's input (Js_eval).

   Expressions compute a value; statements do something, and may leave
   (return, break, continue, throw). The kinds of node, and their names
   where it is cheap, follow ESTree, the tree the JavaScript tools
   (Esprima, Acorn, Babel) agree on:

   cs-history:
   A tree everyone agrees on is recent. Each engine's is its own and
   private. In 2010 Mozilla let scripts see SpiderMonkey's (Dave
   Herman's "Parser API", Reflect.parse); Ariya Hidayat's Esprima
   (2011), a parser written in JavaScript, gave the same tree in any
   browser, and the tools that followed -- to check a program (ESLint),
   to rewrite tomorrow's JavaScript into today's (Babel), to format it
   (Prettier) -- all took and gave that shape, written down as ESTree
   (2015). It is why JavaScript, alone among popular languages, is
   commonly compiled before it is served.

     1 + 2 * 3            Binary ("+", Number 1, Binary ("*", Number 2, Number 3))
     a.b(c)[0]            Index (Call (Member (Name a, "b"), [Name c]), Number 0)
     x => x * 2           Function { params = [x]; body = [Return (x * 2)]; arrow }
     let n = 0            Let (Let_kind, [ ("n", Some (Number 0)) ])

   A statement carries its line, which the interpreter's errors report
   ("x is not defined on line 3"); an expression does not: its
   statement's line is close enough for a program of a page.

   The printer ([expr_to_string], [stmt_to_string]) writes every
   operation in parentheses, so that a test says in one string how the
   parser grouped the operators: 1 + 2 * 3 is "(1 + (2 * 3))". *)
(* ix: the author's mini-chrome's languages/javascript/parsing/Js_ast.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* {1 When each came}

   The nodes are grouped by the edition of the language they arrived
   in, each group under its tag, so that the tree can be read as its
   history -- what is the core of 1997, what ES5 added, what a class
   is an extension of. A node that grew later says so beside it. A new
   node goes in its edition's group, or opens one.

     ES1     1997  the first standard, of Netscape's JavaScript 1.1
                   (1996): what the language was born with in 1995,
                   and little more
     ES3     1999  the language of the first web applications: literals
                   for arrays, objects and regular expressions,
                   function expressions, exceptions, switch
     ES5     2009  ten years later (ES4 was abandoned): getters and
                   setters, strict mode, JSON
     ES2015        "ES6", the largest: let, classes, arrows, templates,
                   destructuring, for-of, modules, promises
     ES2016, ...   an edition a year since: ** (2016), async (2017),
                   object spread (2018), ?. and ?? (2020), class
                   fields (2022) *)

(* opti: a function's body compiled (Js_compile), kept with the
 * function it is of. What it is made of is said later (Js_value:
 * functions over scopes and values, which are not known here): No_code
 * until the function is first called
 * (ix: the code is an exception's value, Js_value.Compiled, where
 * mini-chrome has an open type; and a table of names is a Hashtbl,
 * where it has Hashtbl.Make's of strings: mini-ml has neither) *)
type code = No_code | Code of exn

(* opti: where a name was found the last time it was looked for: how
 * many scopes up, and which slot there (Js_scope.find, which tells the
 * story: an inline cache); -1 scopes up is "not looked for yet". Not
 * part of the syntax, and the one thing here that changes: the parser
 * makes none. Js_quicken puts them in a copy of the tree, in the
 * nodes that are its own: Local, Var_set, a function's frame *)
type place = { mutable hops : int; mutable slot : int }

val place : unit -> place

type expr =
  (* ES1 (1997): values, names, operators, calls *)
  | Number of float
  | String of string
  | Bool of bool
  | Null
  | Name of string (* a variable; undefined is one, the global's *)
  | Local of string * place (* opti: a Name with where it was last found: Js_quicken's, never the parser's *)
  | This
  | Unary of string * expr (* - + ! ~ typeof void delete *)
  | Update of string * bool * expr (* ++ or --, prefix (true) or postfix, on a target *)
  (* + - * / % < > <= >= == != & | ^ << >> >>>; ES3: === !== in
   * instanceof; ES2016: ** *)
  | Binary of string * expr * expr
  | Logical of string * expr * expr (* && ||; ES2020: ??. The right side only if needed *)
  | Assign of string * expr * expr (* = and an operator's (+= ... >>>=; ES2016: **=), on a target *)
  | Conditional of expr * expr * expr (* c ? a : b *)
  | Comma of expr * expr (* a, b: a for what it does, b's value *)
  | Member of expr * string (* o.x *)
  | Index of expr * expr (* o[i] *)
  | Call of expr * expr list (* f(a, b), o.m(a): a method call when f is a Member or an Index *)
  | New of expr * expr list (* new F(a): an object made by F, its prototype F.prototype *)
  (* a function declared; ES3: function (...) {...} as an expression;
   * ES2015: an arrow *)
  | Function of func
  (* ES3 (1999): literals for arrays, objects and regular expressions *)
  | Array of expr list (* [a, b]; ES2015: a ...spread among its items *)
  (* { k: v }; ES5 (2009): get k() { }, set k(v) { }, a keyword as a
   * key; ES2015: k alone, m() { }, [e]: v; ES2018: ...o. Its
   * properties in the order written *)
  | Object of property list
  | Regex of string * string (* /pattern/flags *)
  (* ES2015 ("ES6"): templates, spread, classes *)
  | Template of string list * expr list (* `a${x}b`: its strings (one more than its expressions), and them *)
  | Spread of expr (* ...xs, in an array's items or a call's arguments: each of xs *)
  (* tag`a${x}b`: the function tag called with the strings (an array)
   * and then each value -- a template whose meaning is the tag's:
   * styled-components' css`color: ${c}`, String.raw`\n` *)
  | Tagged of expr * string list * expr list
  (* in a generator (a function* f): yield e gives e to who called next()
   * and stops there until the next one; yield* xs gives each of xs
   * (the bool). Its value: what next(v) was given *)
  | Yield of bool * expr option
  | Class of class_ (* class A extends B { ... } *)
  (* in a class's constructor and methods: super(a) calls the parent's
   * constructor on this; super.m is the parent's m *)
  | Super_call of expr list
  | Super_member of string
  (* ES2020: optional chaining, a?.b, a?.[k], a?.(x). [Opt a] is a, and
   * the end of the chain it is in if a is null or undefined;
   * [Optional] is that chain, undefined then: a?.b.c is Optional
   * (Member (Member (Opt a, b), c)) *)
  | Opt of expr
  | Optional of expr
  (* ES2017: in an async function, await p stops the function until
   * the promise p is settled; its value (Js_promise) *)
  | Await of expr
  | Import_call of expr (* import("m"): a promise of the module's names *)
  | Import_meta (* import.meta: what a module knows of itself, its url *)

(* a function: its name if it has one, its parameters, its body; an
 * arrow's expression body is [Return e]; an arrow has no this of its
 * own; an async one may await *)
and func = {
  name : string option;
  params : (pattern * expr option) list; (* ES1: names; ES2015: patterns, each with its default: (a, b = 1) *)
  rest : pattern option; (* ES2015: (...xs), the arguments left *)
  body : stmt list;
  arrow : bool; (* ES2015 *)
  generator : bool; (* ES2015: function* f() { }, *m() { }: its call gives an iterator over what it yields *)
  async : bool; (* ES2017: async function f() { }, async x => ..., async m() { }: it gives a promise *)
  frame : frame option; (* opti: what its calls have in common: Js_quicken's; None from the parser *)
  (* a function expression with a name (var f = function again(n) { ...
   * again(n - 1) }): the name is the function, in its body, whatever
   * the name means outside. Not a declaration's (its name is the
   * scope's), nor a method's (its key is not a name) *)
  own_name : bool;
  text : (string * int * int) option; (* its own text: the program's, where it starts and ends in it (f.toString()) *)
}

(* opti: a function's frame, known from its text: the names every call
 * of it declares, in the order of their slots (arguments, the var's,
 * the parameters), and their index when they are many; each
 * parameter's slot; whether the parameters are
 * plain names (no default, no pattern); the slot of the function's own
 * name, if it has one in its body (-1: none); whether its text says arguments (a call
 * makes that array only then); and its body compiled, once it has
 * been called (Js_frame, Js_compile) *)
and frame = { names : string array; index : (string, int) Hashtbl.t option; slots : int array; plain : bool; own : int; arguments : bool; mutable code : code }

(* a property of an object literal: its key and its value ("k" alone is
 * k: k; m() { } is m: function () { }), a getter or a setter (a
 * function called when the property is read, or assigned to), or
 * another object's properties *)
and property =
  | Prop of key * expr (* ES3 *)
  (* ES5 *)
  | Getter of key * func
  | Setter of key * func
  | Spread_prop of expr (* ES2018 *)

(* k, "k", 1 (ES3), or [e], computed (ES2015) *)
and key = Key of string | Computed of expr

(* ES2015. A class: its name if it has one, the class it extends, its
 * constructor (None: the default one), and its members *)
and class_ = { class_name : string option; parent : expr option; ctor : func option; members : member list }

(* a member, of the instances' prototype or (static) of the class
 * itself: a method, a getter, a setter (ES2015); or a field, set on
 * each instance when it is made (x = 1: ES2022) *)
and member = { static : bool; key : key; what : member_kind }
(* [Static_block]: static { ... } (ES2022), statements run once when
 * the class is made, this the class *)
and member_kind = Method of func | Get of func | Set of func | Field of expr option | Static_block of stmt list

(* ES2015 (the rest of an object: ES2018). What a declaration, a
 * parameter or a for-of names: one name, or the parts of a value taken
 * apart -- "destructuring":
 *
 *   let { a, b: { c }, d = 1, ...others } = o    a's, o.b.c as c, d or 1
 *   let [x, , y = 2, ...more] = xs               the first, the third or 2
 *
 * an object's parts by their keys (each a pattern and a default), then
 * what is left; an array's by their place (None: one skipped) *)
and pattern =
  | Bind of string
  | Object_pattern of (key * pattern * expr option) list * pattern option
  | Array_pattern of (pattern * expr option) option list * pattern option

and stmt = { line : int; stmt : statement }

and statement =
  (* ES1 (1997) *)
  | Expr of expr
  | Let of let_kind * (pattern * expr option) list (* var a = 1, b; ES2015: let, const, and a pattern: { c } = o *)
  (* opti: var a = 1, b, of plain names, each with where it was last
   * found: Js_quicken's, never the parser's *)
  | Var_set of (string * place * expr option) list
  | Function_decl of func
  | Return of expr option
  | If of expr * stmt * stmt option
  | While of expr * stmt
  | For of stmt option * expr option * expr option * stmt (* for (init; test; update) body *)
  | For_in of for_target * expr * stmt (* for (var k in o) body: o's keys *)
  | Break of string option (* break; ES3: break outer, to a label *)
  | Continue of string option
  | Block of stmt list
  | Empty (* a lone ; *)
  (* with (o) body: in the body, a name that is a property of o is that
   * property. Forbidden in strict mode (ES5), and still what a
   * template compiled to a function relies on (Underscore, Alpine) *)
  | With of expr * stmt
  (* ES3 (1999): do, switch, labels, exceptions *)
  | Do_while of stmt * expr (* do body while (test) *)
  (* switch (e) { case a: ...; default: ... }: each case's test (None:
   * the default) and its statements, which fall into the next's *)
  | Switch of expr * (expr option * stmt list) list
  | Labeled of string * stmt (* outer: for (...) ... *)
  | Throw of expr
  (* try { } catch (e) { } finally { }: the catch or the finally, one at
   * least; ES2019: a catch that takes no name, catch { } *)
  | Try of stmt list * (string option * stmt list) option * stmt list option
  (* ES2015 *)
  | For_of of let_kind * pattern * expr * stmt (* for (let x of xs) body *)
  (* ES2018, in an async function: for await (const x of xs) body --
   * each item awaited before the body has it; xs may give its items
   * late itself (its [Symbol.asyncIterator], whose next() is a promise) *)
  | For_await of let_kind * pattern * expr * stmt
  | Class_decl of class_
  | Import of import_names * string (* import ... from "m": a module's first lines *)
  | Export of export

(* import d, * as ns, { a, b as c } from "m": the default's name here,
 * the name of the whole, and each (name there, name here) *)
and import_names = { default : string option; namespace : string option; named : (string * string) list }

and export =
  | Export_decl of stmt (* export const x = 1, export function f, export class C *)
  | Export_default of expr (* export default e *)
  | Export_default_decl of stmt (* export default function f / class C: named here too *)
  | Export_names of (string * string) list * string option (* export { a, b as c } [from "m"]: (name here or there, name out) *)
  | Export_all of string option * string (* export * [as ns] from "m" *)

(* what a for-in sets at each turn: a name it declares (for (var k in
 * o)), or something assigned to (for (k in o), for (o.k in o)) *)
and for_target = Declared of let_kind * string | Target of expr

(* var: ES1; let and const: ES2015 *)
and let_kind = Let_kind | Const_kind | Var_kind

type program = stmt list

(* a number as JavaScript prints it: 7, not 7.0; 0.5; the shortest
 * digits that read back as the same float (0.1 + 0.2 is
 * 0.30000000000000004); NaN, Infinity, -Infinity *)
val number_to_string : float -> string

(* fully parenthesized: (1 + (2 * 3)), f((x) => (x * 2), 3) *)
val expr_to_string : expr -> string

(* one line per statement, a body's statements in brackets:
 *   Let a 1
 *   If ((b > a), Block [Expr (b = 0)], Expr (b = 1))
 *   Function f [] [Return; Expr a] *)
val stmt_to_string : stmt -> string
