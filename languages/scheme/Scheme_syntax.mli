(* Scheme_syntax: from what was read to code, the special forms
   checked and most of them rewritten into a few.

   Scheme has seven forms the machine knows (Scheme.mli's [desc]):
   quote, a variable, lambda, if, set!, a call, and begin -- plus
   define at the top. Everything else is *derived* (R5RS, section 7.3,
   defines them this way), rewritten here before running:

       (let ((x 1)) body)      ((lambda (x) body) 1)
       (let* ((x 1) (y x)) b)  (let ((x 1)) (let ((y x)) b))
       (letrec ((f e)) b)      ((lambda () (define f e) b))
       (let loop ((i 0)) b)    ((letrec ((loop (lambda (i) b))) loop) 0)
       (and a b)               (if a b #f)
       (or a b)                (let ((t a)) (if t t b))
       (cond [q a] [else b])   (if q a b)
       (when c a b)            (if c (begin a b) (void))
       `(a ,b ,@c)             (cons 'a (cons b (append c '())))

   and a body's defines become variables of the body, set in turn, as
   letrec* does. The hidden variable of or is named " t", with a space,
   which no program can write: the rewriting's hygiene, cheaply.

   An error says which form and what it expected, DrScheme's way, and
   carries the span of the text at fault, which DrScheme paints pink:

       (define (f) )   define: expected an expression for the
                       function's body, but nothing's there

   Where it stands: after Sexpr_read, before either machine, which
   never see a let or a cond: Scheme_eval and Scheme_secd are small
   because this module is where the language's size is. Scheme_step
   does not go through it: a student must see the cond he wrote, not
   the ifs it becomes.

   terminology:
   *Hygiene* is the name of two accidents a rewriting can have. A
   name it brings in may catch the program's: (or a t), rewritten
   with a variable called t, would test a and then give back the
   hidden t, never the program's. And a name it uses may be caught
   by the program's: `(a ,b) rewritten to (cons 'a ...) would call
   whatever cons means where the quasiquote is written, (let ((cons
   +)) ...) included. Here the first is avoided by a name nobody can
   type, the second by putting the procedure itself in the code, not
   its name; both work because the rewritings are few and written in
   OCaml, by us.

   cs-history:
   Lisp's macros are rewritings a program adds, and had both
   accidents for twenty years, avoided by hand with gensym, a fresh
   name asked of the system. Eugene Kohlbecker, Daniel Friedman,
   Matthias Felleisen and Bruce Duba (1986) made the expander do the
   renaming, so that a macro's names mean what they meant where the
   macro was written, as a procedure's do: lexical scope, for
   macros. syntax-rules, patterns and templates with that guarantee,
   is in the reports since R4RS's appendix (1991) and R5RS proper.
   There is no define-syntax here: the derived forms are a fixed
   list, and a program cannot add one.

   design:
   A small core and the rest by rewriting is how the lambda papers
   proceed ("Lambda: The Ultimate Imperative" writes the loops, the
   assignments and the jumps of other languages as lambdas) and how
   a compiler is kept small: every pass after this one knows seven
   forms. Smalltalk goes further and has no form at all, a
   conditional being a message (St_ast.mli); the price there is a
   compiler that must recognize ifTrue: to make it fast.

   References: R5RS (1998), section 7.3, "Derived expression types",
   which gives each as a syntax-rules macro, and section 4.3 for
   macros. Kohlbecker, Friedman, Felleisen and Duba, "Hygienic Macro
   Expansion" (LISP and Functional Programming, 1986). William
   Clinger and Jonathan Rees, "Macros That Work" (POPL 1991). Guy
   Steele and Gerald Sussman, "Lambda: The Ultimate Imperative" (MIT
   AI Memo 353, 1976). *)

exception Error of string * Sexpr.span

(* [top x]: a form of the Definitions window or the prompt: a
   definition, define-struct, or an expression *)
val top : Sexpr.t -> Scheme.expr

(* [datum x]: the value of (quote x): a symbol, a list... *)
val datum : Sexpr.t -> Scheme.t
