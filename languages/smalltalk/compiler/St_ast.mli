(* St_ast: a Smalltalk-80 method or expression, as a tree.

   The whole language is five kinds of expression -- a literal, a
   variable, an assignment, a message sent, a block -- and a cascade,
   several messages to one receiver ("Transcript show: 'a'; cr").
   There is no if, no loop, no operator: "x > 0 ifTrue: [...]" is the
   message ifTrue: sent to a Boolean with a block, and "3 + 4" the
   message + sent to 3. What makes it fast anyway is the compiler's
   business (St_compile.mli, the inlined messages).

   A method is a pattern (its selector and argument names), its
   temporaries, perhaps a primitive's number, and statements; a
   statement is an expression, or a return (^). Each node keeps where
   it is in the text, [start, stop), for the compiler's errors and for
   the debugger, which highlights the message being sent.

     a at: i + 1 put: b sqrt          one send of at:put:, two arguments

                    Send "at:put:"
                   /       |        \
              Var a     Send "+"     Send "sqrt"
                        /     \          |
                     Var i   Lit 1     Var b

   St_parse makes the tree, St_compile walks it once (twice with
   closures) and nothing else reads it: the system keeps a method's
   text and its bytecodes, not its tree.

   design:
   Control as messages needs one thing of the language: a way to hand
   over code not yet run, the block. "x > 0 ifTrue: [...]" can be a
   message because the brackets delay what is inside until the Boolean
   sends it value. It is Scheme's argument seen from the other side
   (Scheme_syntax.mli): there a few special forms are kept and the
   rest rewritten into them, and the lambda papers show that a lambda
   would do for those too; here there is no special form at all, and
   the compiler puts the jumps back where it can.

   others:
   Smalltalk-72 had no such tree: a method was a list of tokens
   that the receiver read as it ran. The syntax of 1976 that made
   a compiler, and this tree, possible: St_parse. *)

type pos = int * int

type literal =
  | L_int of int
  | L_large of bool * int list (* negative?, the magnitude's bytes, least significant first *)
  | L_float of float
  | L_char of char
  | L_string of string
  | L_symbol of string
  | L_array of literal list
  | L_nil (* true, false and nil inside a literal array *)
  | L_true
  | L_false

type expr = { e : desc; pos : pos }

and desc =
  | Lit of literal
  | Var of string (* self, super, nil, true, false, thisContext included *)
  | Assign of string * expr
  | Send of expr * string * expr list
  (* a receiver, then messages to it, each with where its selector
   * starts and its arguments end *)
  | Cascade of expr * (string * expr list * pos) list
  | Block of string list * string list * stmt list (* arguments, temporaries, statements *)

and stmt = Expr of expr | Return of expr * pos

type method_ = {
  selector : string;
  args : string list;
  temps : string list;
  primitive : int option;
  body : stmt list;
}

(* how many arguments a selector takes: its colons, or one for a
 * binary selector *)
val arity : string -> int

(* an expression or a statement as the tests write it, every message
 * in parentheses: "((3 + 4) * 2)" *)
val show_expr : expr -> string
val show_stmt : stmt -> string

(* a literal as Smalltalk prints it: 3, $a, 'it''s', #foo, #(1 2) *)
val show_literal : literal -> string
