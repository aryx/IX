(* Js_parse: JavaScript's tokens grouped into a tree -- statements by
   recursive descent, expressions by Pratt's top-down operator
   precedence.

   (mini-chrome's notes_javascript.md, sections 2 and 3.)

   Where it stands: Js_eval.eval parses a script's text and runs it;
   Js_module a module's, whose import and export statements are read
   here too; a page's scripts come by Browser_script, a line typed by
   mini-node's CLI. Template literals come back here from the lexer
   as tokens, a small parse inside the parse.

   {2 Statements: recursive descent}

   A statement says what it is by its first token -- let, const, var,
   function, if, while, for, return, break, continue, throw, try, {,
   ; -- or else it is an expression. One function per statement, each
   calling the one it needs next, as Formula.mli's grammar does: the
   grammar and the code are the same shape.

   **Semicolons.** A statement ends at ";", or -- JavaScript's
   automatic semicolon insertion, the simple half kept here -- before a
   "}", at the end of the text, or before a token on a new line. So
   the lexer remembers newlines. The rule's famous trap is kept too,
   since the rule gives it: "return" alone on its line returns
   nothing, and the expression on the next line is a statement of its
   own (ECMAScript's [no LineTerminator here], which also keeps "x\n++y"
   from being "x++; y"). The rule's other half is JavaScript's too,
   with no line written for it: a line starting with ( or [ continues
   the one before, because the loop of an expression (below) takes a
   call or an index before the statement asks whether it has ended.

     return            var a = 1
       5               (function () { ... })()
     // undefined      // TypeError: 1 is not a function

   {2 Expressions: Pratt}

   1 + 2 * 3 is 1 + (2 * 3): multiplication binds tighter. Recursive
   descent says it with one function per level of precedence (Formula:
   an expr is terms, a term factors); JavaScript has a dozen levels.
   Vaughan Pratt's way gives each operator a number, its **binding
   power**, and one loop does them all:

     expression (min):
       left <- a prefix thing: a number, a name, ( ... ), -x, [ ... ], { ... }, a function
       while the next operator binds at least as tight as min:
         take it; right <- expression (its power + 1, or its power if right-associative)
         left <- (left op right)

     power  operators                         associativity
       0    ,                                 left: a, b is a done, then b's value
       1    = += -= ... >>>= &= |= ^=         right: a = b = 1 is a = (b = 1)
       2    ? :                               right
       3    ??                                left
       4    ||                                left
       5    &&                                left
       6    |                                 left
       7    ^                                 left
       8    &                                 left
       9    === !== == !=                     left
      10    < > <= >= in instanceof           left
      11    << >> >>>                         left
      12    + -                               left: 1 - 2 - 3 is (1 - 2) - 3
      13    * / %                             left
      14    **                                right: 2 ** 3 ** 2 is 2 ** 9
      15    prefix - + ! ~ typeof void delete ++ --
      16    postfix . [ ] ( ) ++ --           left: a.b(c)[d] is ((a.b)(c))[d]

   Where a comma separates things (a call's arguments, an array's
   items, a var's names), each is read from power 1: the comma is then
   not an operator. And the two sides of ? : are read from 1 too, so
   that each may be an assignment (c ? a = 1 : b = 2).

   "in" is an operator, and also the word of for (k in o): in a for's
   first part it is the for's, unless inside brackets.

   comeback:
   Pratt's paper is of 1973, and was nearly forgotten. He wrote it for
   CGOL, a notation with infix operators for Lisp; the method is a few
   lines, needs no tool, and gives each operator its meaning as data.
   But the same years gave parsing its theory -- LR (Knuth, 1965), yacc
   (Johnson, 1975) -- and the textbooks (the "Dragon Book", 1977)
   taught grammars and generators, which could prove what they
   accepted; a loop over a table of numbers looked like a trick.
   Compilers went on using it quietly ("precedence climbing", in GCC
   and later Clang). It came back by name through JavaScript: Douglas
   Crockford used it for JSLint and told of it in "Beautiful Code"
   (2007), and a generation that had to parse a language whose grammar
   no generator takes well (below) made it the usual way again.

   {2 Patterns}

   Where a name is declared -- let, a parameter, for-of -- there may be
   a **pattern** instead, taking a value apart (Js_ast.pattern):
   { a, b: c = 1, ...rest } an object's properties, [x, , y] an array's
   items. A parameter may have a default (b = 1), and the last may take
   the rest (...xs). The same shapes on the left of an "=" are read
   first as an array or an object literal, and taken as a pattern when
   assigned to (Js_eval.assign): [a, b] = [b, a].

   An object literal's properties: k: v; k alone (k: k); m() { } (a
   method); [e]: v (a computed key); get k() { } and set k(v) { }
   (functions called when k is read, and assigned to); ...o. And
   ...xs in an array's items and a call's arguments.

   A template literal comes from the lexer as its strings and the
   tokens of each ${ }, read here as expressions.

   {2 Classes, and chains that may end}

   class A extends B { ... } is read member by member: a method m() { },
   an accessor (get k() { }, set k(v) { }), a field (k = e), each
   perhaps static; "constructor" is the class's own function. "get",
   "set" and "static" are such words only before a member's name:
   alone before a "(", they are a method's name. Inside, "super(" and
   "super." are the parent's constructor and methods.

   a?.b is read with all that follows it -- .c, [d], (e), other ?. --
   as one chain (Js_ast.Optional), so that a null a ends all of it and
   not one step: a?.b.c is undefined, not an error on ".c".

   Left-associative: the right side is read with power + 1, so the next
   operator of the same power stops it and becomes the loop's next;
   right-associative: with the same power, so it goes on. That "+ 1" is
   the whole difference.

   An arrow function looks like something else until its "=>": "x"
   is a name, and "(a, b)" a parenthesized expression, until the arrow
   comes. The spec parses them as expressions and turns them into
   parameters afterwards ("cover grammars"); here, seeing "(" or a
   name, the parser looks ahead for the ")" and the "=>" first -- the
   tokens are all in an array, so looking ahead costs nothing.

   Worked example (the tests'):

     1 + 2 * 3 - 4          ((1 + (2 * 3)) - 4)
     a = b = c || d && e    (a = (b = (c || (d && e))))
     -x.y(1)[0]             (-(((x.y)(1))[0]))
     f(x => x * 2, 3)       (f((x) => (x * 2), 3))

   {2 Why not yacc}

   In mini-chrome, where this parser is from, the house has no parser
   generator: every parser there is written by hand (Formula, BASIC,
   HyperTalk, the HTML tokenizer, CSS), and the author's other
   projects use ocamlyacc where it fits (xix's assemblers, in Plan 9's
   tradition). In ix the rule is the other way: a real grammar is
   ocamlyacc's (mini-cc's, mini-ml's, awk's, hoc's and bc's Parser are
   .mly files), and a parser by hand must say why. yacc is also the
   classic way to teach parsing: the grammar is the program, the
   precedences declarations. So why not here? Because JavaScript's
   grammar fights LALR(1) at every turn a teaching parser cares about:

   - **Arrow functions.** After "(a, b" the parser cannot know
     whether it reads a parenthesized expression (a comma expression)
     or a parameter list until it meets the "=>", arbitrarily far
     away. An LALR(1) parser decides with one token of lookahead; the
     grammar has conflicts, or grows the cover-grammar tricks that make
     it unreadable. By hand, a scan ahead in the token array.
   - **Semicolons and newlines.** "A newline may end a statement" and
     "return alone on its line returns nothing" need the parser and
     the lexer to talk: the spec defines insertion as "where the next
     token is not allowed", which yacc can only imitate with error
     productions, and [no LineTerminator here] needs the lexer to know
     the parser's state.
   - **{ at the start of a statement** is a block; anywhere else, an
     object literal: more context the tokens alone don't give.
   - **Error messages.** A teaching engine should say "expected ')' on
     line 3"; yacc says "syntax error" unless much is added by hand.

   modern:
   And what real engines do: every one parses JavaScript by hand --
   V8, SpiderMonkey, JavaScriptCore, QuickJS, and the tools' parsers
   Acorn, Esprima, Babel -- recursive descent for statements and
   precedence climbing (Pratt's idea) for expressions.

   Nothing is lost for the lesson: the binding powers above *are*
   yacc's %left and %right declarations, as data --

     yacc                          Pratt (the table above)
     %right '=' PLUS_EQ ...        1, right
     %left OR                      4
     %left AND                     5
     %left '+' '-'                 12
     %left '*' '/' '%'             13
     %right UMINUS '!' TYPEOF      15 (prefix)

   -- the later a %left line, the higher its power; and "%prec UMINUS"
   is the prefix operator's own power. Where yacc shines is a language
   designed for it: Wirth's Pascal (the TinyTurboPascal of
   mini-chrome's plan_terminal.md) or a C subset. The expressions of
   this parser, written again in ocamlyacc and compared, are an
   exercise (mini-chrome's notes_javascript.md).

   The comparison can be read in ix as it is, since the other side is
   written: mini-cc's Parser, a .mly, has for C the very lines of the
   table above, from its %left COMMA and %right ASSIGN down to %left
   STAR SLASH PERCENT, in the same order -- JavaScript's operators and
   their precedences are C's, through Java, with === ?? ** and >>>
   added. And the shell's Parser is the third way, with neither a
   table nor a tool: a function a level, which a grammar of few
   levels can afford.

   evolution:
   The table carries a mistake fifty years old. & ^ | bind looser
   than == (8, 7 and 6 against 9), so "x & 1 == 0" is x & (1 == 0).
   In B and the first C, & and | were also the logical operators, and
   a condition such as a == b & c == d needed that order; when && and
   || were added the order of & and | was left as it was, there being
   by then programs that relied on it. Dennis Ritchie tells it, and
   that the other order would have been better ("The Development of
   the C Language", 1993). Java copied C, and JavaScript Java.

   Reference: Vaughan Pratt, "Top Down Operator Precedence" (POPL,
   1973); Douglas Crockford, "Top Down Operator Precedence" (2007);
   Robert Nystrom, "Pratt Parsers: Expression Parsing Made Easy"
   (2011) and Crafting Interpreters, chapter 17; ECMAScript, sections
   13 and 14 (expressions, statements) and 12.10 (automatic semicolon
   insertion); Stephen C. Johnson, "Yacc: Yet Another
   Compiler-Compiler" (Bell Labs, 1975). *)
(* ix: the author's mini-chrome's languages/javascript/parsing/Js_parse.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* a mistake: its line and what was expected *)
type error = { line : int; message : string }

(* the program, or its first mistake (Js_lexer's included). A long
 * text lets the window be drawn as it is read (Js_slice.breath) --
 * but not one read [aside], by a thread that is not the window's run
 * (a worker of the pool reading ahead): a slice is the run's to end *)
(* ix: was the environment's JS_SYNTAX=1: the tokens before the one
 * refused said too, in the error's message *)
val syntax_context : bool ref

val parse_with : aside:bool -> string -> (Js_ast.program, error) result

(* the same, not aside (ix: it was parse's ?aside) *)
val parse : string -> (Js_ast.program, error) result

(* one expression alone (the tests', and a console's) *)
val parse_expression : string -> (Js_ast.expr, error) result
