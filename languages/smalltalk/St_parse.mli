(* St_parse: Smalltalk-80's grammar, by recursive descent.

   The grammar fits in ten lines, and the parser is those ten lines
   written out (Blue Book, chapter 2 and its syntax diagrams; [x] is
   an optional x, {x} any number of them):

     method     ::= pattern [temporaries] [primitive] statements
     pattern    ::= unary | binary name | keyword name {keyword name}
     statements ::= [statement {"." statement}] ["."]
     statement  ::= "^" expression | expression
     expression ::= name ":=" expression | cascade
     cascade    ::= keywordExpr {";" message}
     keywordExpr::= binaryExpr {keyword binaryExpr}
     binaryExpr ::= unaryExpr {binarySelector unaryExpr}
     unaryExpr  ::= primary {name}
     primary    ::= literal | name | block | "(" expression ")"
     block      ::= "[" {":" name} ["|"] [temporaries] statements "]"

   The precedence is in the nesting: unary messages bind tightest, then
   binary, then keyword. And all binary selectors have the *same*
   precedence, from left to right: "3 + 4 * 2" is 14, not 11, which
   surprises everyone once (the usual defence: a language where
   anyone defines operators cannot know which of them multiplies):

     3 + 4 * 2                  ((3 + 4) * 2)
     a at: i + 1 put: b sqrt    (a at: (i + 1) put: (b sqrt))

   A cascade sends several messages to the receiver of the last one:
   "Transcript show: 'a'; cr" sends show: then cr to Transcript.

   A mistake is reported where it is, with Smalltalk-80's messages
   (the Browser inserts them into the text there, as the original's
   compiler did): "Nothing more expected", "Argument expected", "]
   expected"...

   Where it stands: between St_lexer and St_compile, which calls it
   on a method's text ([parse_method]) and on a Workspace's line
   ([parse_doit]). A function a rule, as mini-rc's Parser is written,
   where the C and ML compilers of ix have a grammar for yacc: ten
   rules and no precedence table do not need the tool.

   cs-history:
   This grammar is Smalltalk-76's. Smalltalk-72 had none to write
   down, each class reading its own messages; the three kinds of
   message, told apart by their shape alone, are what Dan Ingalls
   fixed in 1976 so that a method could be compiled, and a reader
   could tell where an expression ends without knowing the classes.

   others:
   No precedence among operators is rare and not alone: APL has
   none either, and goes from right to left, so 3 + 4 * 2 is 11
   there by another road. Lisp has no operators to rank. The keyword
   message is the part that travelled: Objective-C's
   [a at: i put: x] is this syntax inside brackets, and Swift's
   labelled arguments, a.insert(x, at: i), come from there. What
   they keep is that a call reads as a sentence and no one has to
   remember which argument comes first.

   References: the Blue Book, chapter 2, "Expression Syntax", and
   its syntax diagrams. *)

exception Error of int * string

(* a method, as the Browser accepts it: its pattern first *)
val parse_method : string -> St_ast.method_

(* what a Workspace's "do it" runs: temporaries, then statements, as
 * the body of a method with no arguments, selector "DoIt" *)
val parse_doit : string -> St_ast.method_

(* one literal, or its absence: "#(1 $a)" *)
val parse_literal : string -> St_ast.literal option

(* the selector of a method's text, read from its pattern, without
 * the rest parsed ("at: i put: x ^x" is "at:put:") *)
val selector_of : string -> string option
