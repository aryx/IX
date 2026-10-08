/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* ocaml-light's grammar (its parsing/parser.mly, OCaml 1.07's), for the
 * subset: no objects, attributes, let-operators or lazy, which its
 * parser skips or accepts for xix's sake and mini-9pi doesn't use. The
 * precedences are OCaml's, so that ; is looser than if, a match inside
 * a match's clause takes the clauses after it, and f x :: l is
 * (f x) :: l. The sugar is undone here (Ast's comment).
 *
 * A list or an optional part is menhir's standard rule where one fits
 * (x*, x+, x?, separated_nonempty_list(sep, x)...; mini-yacc reads
 * them). Their lists are recursive on the right, so three kinds stay
 * rules of their own, recursive on the left: a list that may end with
 * its separator ([ a; b; ]: at a ; the parser would have to know
 * whether an element follows), a list a precedence decides (a tuple's
 * commas, a match's clauses: a made rule has no %prec), and a choice
 * one token doesn't make (type t = | A: an optional | before a
 * constructor, against a type's name). */
%{
open Ast

(* Where a rule's text is, or one of its symbols': an action's $sloc
 * and $loc($n), each a first and a last position, given to what builds
 * the tree (at). They are menhir's, which mini-yacc reads too: menhir
 * keeps no state for Parsing's functions (symbol_start_pos...) to ask. *)
let line at = (fst at).Lexing.pos_lnum
(* mlpp: its constructs need where things are, in characters (Ast's span) *)
let span at = (fst at).Lexing.pos_cnum, (snd at).Lexing.pos_cnum

(* mlpp: espan *)
let mkexp at e = { e; eloc = line at; espan = span at }
let mkpat at p = { p; ploc = line at }
let mkitem at i = { i; iloc = line at }
let mksig at s = { s; sloc = line at }
let ident at x = mkexp at (Eident [ x ])
(* mlpp: the operator's espan its own (a class's operator) *)
let infix at at_op a op b = mkexp at (Eapply ({ (ident at op) with espan = span at_op }, [ a; b ]))
let unit at = mkexp at (Econstruct ([ "()" ], None))

(* -e is ~-e, -1 the constant, -. the float's *)
let uminus at op e =
  match op, e.e with
  | "-", Econst (Int n) -> mkexp at (Econst (Int (-n)))
  | "-", Econst (Int32 n) -> mkexp at (Econst (Int32 ("-" ^ n)))
  | "-", Econst (Int64 n) -> mkexp at (Econst (Int64 ("-" ^ n)))
  | ("-" | "-."), Econst (Float f) -> mkexp at (Econst (Float ("-" ^ f)))
  | _ -> mkexp at (Eapply (ident at ("~" ^ op), [ e ]))

let rec mklist at = function
  | [] -> mkexp at (Econstruct ([ "[]" ], None))
  (* mlpp: espan *)
  | e :: l ->
      { e = Econstruct ([ "::" ], Some { e = Etuple [ e; mklist at l ]; eloc = e.eloc; espan = e.espan }); eloc = e.eloc; espan = e.espan }

let rec mkpatlist at = function
  | [] -> mkpat at (Pconstruct ([ "[]" ], None))
  | p :: l -> { p = Pconstruct ([ "::" ], Some { p = Ptuple [ p; mkpatlist at l ]; ploc = p.ploc }); ploc = p.ploc }

(* fun p q -> e: a function of p whose body is a function of q *)
let mkfun at p e = mkexp at (Efunction [ p, None, e ])

let array_op at m f args = mkexp at (Eapply (mkexp at (Eident [ m; f ]), args))

(* match e with p -> a | exception E -> h: the value's clauses outside
 * the try, so that an exception of a isn't caught, as
 * (try let v = e in fun () -> match v with p -> a with E -> fun () -> h) () *)
let mkmatch at e cases =
  let mkexp = mkexp at and mkpat = mkpat at in
  let exns, values = List.partition (fun ((p : pattern), _, _) -> match p.p with Pexception _ -> true | _ -> false) cases in
  if exns = [] then mkexp (Ematch (e, cases))
  else begin
    let v = Printf.sprintf "match__%d" (line at) in
    let thunk body = mkexp (Efunction [ mkpat (Pconstruct ([ "()" ], None)), None, body ]) in
    let handlers = List.map (fun ((p : pattern), g, h) -> (match p.p with Pexception q -> q | _ -> p), g, thunk h) exns in
    let body = mkexp (Elet (Nonrec, [ mkpat (Pvar v), e ], thunk (mkexp (Ematch (ident at v, values))))) in
    mkexp (Eapply (mkexp (Etry (body, handlers)), [ unit at ]))
  end

(* { x; M.y }: a field of the variable of its name *)
let last l = List.nth l (List.length l - 1)

(* mlpp: the [@@...] after a group of types: its last's, as in OCaml's tree *)
let with_attribute ds a =
  match List.rev ds with d :: l -> List.rev ({ d with tattrs = d.tattrs @ [ a ] } :: l) | [] -> ds
%}

%token <int> INT
%token <string> INT32 INT64 LABEL
%token TILDE
%token <char> CHAR
%token <string> FLOAT STRING LIDENT UIDENT
%token <string> PREFIXOP INFIXOP0 INFIXOP1 INFIXOP2 INFIXOP3 INFIXOP4 SUBTRACTIVE
%token AND AS ASSERT BEGIN DO DONE DOWNTO ELSE END EXCEPTION EXTERNAL FALSE FOR FUN FUNCTION IF IN LET MATCH
%token MODULE MUTABLE OF OPEN OR REC SIG STRUCT THEN TO TRUE TRY TYPE VAL WHEN WHILE WITH
%token LPAREN RPAREN LBRACE RBRACE LBRACKET RBRACKET LBRACKETBAR BARRBRACKET
/* mlpp: [% and [@@deriving */
%token LBRACKETPERCENT DERIVING CLASS INSTANCE
%token <string> LETOP
/* objects: their types and :>, ix's capabilities */
%token COLONGREATER
%token AMPERSAND AMPERAMPER BAR BARBAR COLON COLONCOLON COLONEQUAL COMMA DOT DOTDOT EQUAL GREATER LESS
%token LESSMINUS MINUSGREATER QUOTE SEMI SEMISEMI STAR UNDERSCORE
%token EOF

/* from the loosest */
%right SEMI
%right prec_fun prec_match prec_try
%right prec_if
%right COLONEQUAL LESSMINUS
%left AS
%left BAR
%left COMMA
%right OR BARBAR
%right AMPERSAND AMPERAMPER
%left INFIXOP0 EQUAL LESS GREATER
%right INFIXOP1
%right COLONCOLON
%left INFIXOP2 SUBTRACTIVE
%left INFIXOP3 STAR
%right INFIXOP4
%right prec_unary_minus
%right prec_constr_appl
%left DOT
%right PREFIXOP

%start implementation interface
%type <Ast.structure> implementation
%type <Ast.signature> interface

%%

implementation:
  | structure EOF { $1 }
;
interface:
  | signature_element* EOF { $1 }
;

/* modules */

structure:
  | structure_tail { $1 }
  | seq_expr structure_tail { mkitem $sloc (Ieval $1) :: $2 }
;
structure_tail:
  | /* empty */ { [] }
  | SEMISEMI { [] }
  | SEMISEMI seq_expr structure_tail { mkitem $sloc (Ieval $2) :: $3 }
  | SEMISEMI structure_item structure_tail { $2 :: $3 }
  | structure_item structure_tail { $1 :: $2 }
;
structure_item:
  | LET rec_flag separated_nonempty_list(AND, let_binding) instance
      { match $3 with
        | [ ({ p = Pany; _ }, e) ] -> mkitem $sloc (Ieval e)
        | bs -> mkitem $sloc (Ivalue ($2, bs, $4)) }
  | EXTERNAL val_ident COLON core_type EQUAL STRING+ { mkitem $sloc (Iexternal ($2, $4, $6)) }
  | TYPE type_declarations { mkitem $sloc (Itype $2) }
  /* mlpp: [@@deriving show] */
  | TYPE type_declarations attribute { mkitem $sloc (Itype (with_attribute $2 $3)) }
  | EXCEPTION UIDENT constructor_arguments { mkitem $sloc (Iexception ($2, $3)) }
  | MODULE UIDENT module_binding { mkitem $sloc (Imodule ($2, $3)) }
  | OPEN mod_longident { mkitem $sloc (Iopen $2) }
;
/* mlpp: */
attribute:
  | DERIVING LIDENT* RBRACKET { { aname = "deriving"; aargs = $2; aloc = line $sloc; aend = snd (span $sloc) } }
  | CLASS { { aname = "class"; aargs = []; aloc = line $sloc; aend = snd (span $sloc) } }
;
/* mlpp: let show_int : int show = ... [@@instance] */
instance:
  | /* empty */ { [] }
  | INSTANCE { [ { aname = "instance"; aargs = []; aloc = line $sloc; aend = snd (span $sloc) } ] }
;
module_binding:
  | EQUAL module_expr { $2 }
  | COLON module_type EQUAL module_expr { Mconstraint ($4, $2) }
;
module_expr:
  | mod_longident { Mident $1 }
  | STRUCT structure END { Mstruct $2 }
  | LPAREN module_expr COLON module_type RPAREN { Mconstraint ($2, $4) }
  | LPAREN module_expr RPAREN { $2 }
;
signature_element:
  | signature_item SEMISEMI? { $1 }
;
signature_item:
  | VAL val_ident COLON core_type instance { mksig $sloc (Sval ($2, $4, $5)) }
  | EXTERNAL val_ident COLON core_type EQUAL STRING+ { mksig $sloc (Sexternal ($2, $4, $6)) }
  | TYPE type_declarations { mksig $sloc (Stype $2) }
  /* mlpp: */
  | TYPE type_declarations attribute { mksig $sloc (Stype (with_attribute $2 $3)) }
  | EXCEPTION UIDENT constructor_arguments { mksig $sloc (Sexception ($2, $3)) }
  | MODULE UIDENT COLON module_type { mksig $sloc (Smodule ($2, $4)) }
  | OPEN mod_longident { mksig $sloc (Sopen $2) }
;
module_type:
  | mod_longident { MTident $1 }
  | SIG signature_element* END { MTsig $2 }
  | LPAREN module_type RPAREN { $2 }
;

/* expressions */

seq_expr:
  | expr { $1 }
  | expr SEMI { $1 }
  | expr SEMI seq_expr { mkexp $sloc (Eseq ($1, $3)) }
;
expr:
  | simple_expr { $1 }
  | constr_longident simple_expr { mkexp $sloc (Econstruct ($1, Some $2)) }
  | expr COLONCOLON expr { mkexp $sloc (Econstruct ([ "::" ], Some (mkexp $sloc (Etuple [ $1; $3 ])))) }
  | simple_expr DOT label_longident LESSMINUS expr { mkexp $sloc (Esetfield ($1, $3, $5)) }
  /* mlpp: a generator of [%list] */
  | LIDENT LESSMINUS expr { mkexp $sloc (Egenerator ($1, $3)) }
  | expr_comma_list { mkexp $sloc (Etuple (List.rev $1)) }
  | FUNCTION BAR? match_cases %prec prec_fun { mkexp $sloc (Efunction (List.rev $3)) }
  | FUN parameter fun_def { mkfun $sloc $2 $3 }
  | simple_expr argument+ { mkexp $sloc (Eapply ($1, $2)) }
  | LET rec_flag separated_nonempty_list(AND, let_binding) IN seq_expr { mkexp $sloc (Elet ($2, $3, $5)) }
  /* let* x = e in body: ( let* ) e (fun x -> body), whatever let* is where it is written */
  | LETOP let_binding IN seq_expr { mkexp $sloc (Eapply (ident $sloc $1, [ snd $2; mkfun $sloc (fst $2) $4 ])) }
  | expr INFIXOP0 expr { infix $sloc $loc($2) $1 $2 $3 }
  | expr INFIXOP1 expr { infix $sloc $loc($2) $1 $2 $3 }
  | expr INFIXOP2 expr { infix $sloc $loc($2) $1 $2 $3 }
  | expr INFIXOP3 expr { infix $sloc $loc($2) $1 $2 $3 }
  | expr INFIXOP4 expr { infix $sloc $loc($2) $1 $2 $3 }
  | expr SUBTRACTIVE expr { infix $sloc $loc($2) $1 $2 $3 }
  | expr STAR expr { infix $sloc $loc($2) $1 "*" $3 }
  | expr EQUAL expr { infix $sloc $loc($2) $1 "=" $3 }
  | expr LESS expr { infix $sloc $loc($2) $1 "<" $3 }
  | expr GREATER expr { infix $sloc $loc($2) $1 ">" $3 }
  | expr BARBAR expr { infix $sloc $loc($2) $1 "||" $3 }
  | expr OR expr { infix $sloc $loc($2) $1 "or" $3 }
  | expr AMPERAMPER expr { infix $sloc $loc($2) $1 "&&" $3 }
  | expr AMPERSAND expr { infix $sloc $loc($2) $1 "&" $3 }
  | expr COLONEQUAL expr { infix $sloc $loc($2) $1 ":=" $3 }
  | SUBTRACTIVE expr %prec prec_unary_minus { uminus $sloc $1 $2 }
  | MATCH seq_expr WITH BAR? match_cases %prec prec_match { mkmatch $sloc $2 (List.rev $5) }
  | TRY seq_expr WITH BAR? match_cases %prec prec_try { mkexp $sloc (Etry ($2, List.rev $5)) }
  | IF seq_expr THEN expr ELSE expr %prec prec_if { mkexp $sloc (Eif ($2, $4, Some $6)) }
  | IF seq_expr THEN expr %prec prec_if { mkexp $sloc (Eif ($2, $4, None)) }
  | WHILE seq_expr DO seq_expr DONE { mkexp $sloc (Ewhile ($2, $4)) }
  | FOR val_ident EQUAL seq_expr direction_flag seq_expr DO seq_expr DONE { mkexp $sloc (Efor ($2, $4, $6, $5, $8)) }
  | simple_expr DOT LPAREN seq_expr RPAREN LESSMINUS expr { array_op $sloc "Array" "set" [ $1; $4; $7 ] }
  | simple_expr DOT LBRACKET seq_expr RBRACKET LESSMINUS expr { array_op $sloc "Bytes" "set" [ $1; $4; $7 ] }
  | ASSERT simple_expr { mkexp $sloc (Eassert $2) }
;
simple_expr:
  | constant { mkexp $sloc (Econst $1) }
  /* mlpp: the parentheses in espan, a [%bits] clause's body may start with one */
  | LPAREN seq_expr RPAREN { { $2 with espan = span $sloc } }
  | BEGIN seq_expr END { { $2 with espan = span $sloc } }
  | BEGIN END { unit $sloc }
  | constr_longident { mkexp $sloc (Econstruct ($1, None)) }
  /* mlpp: the brackets in espan */
  | LBRACKET expr_semi_list SEMI? RBRACKET { { (mklist $sloc (List.rev $2)) with espan = span $sloc } }
  | LBRACE lbl_expr_list SEMI? RBRACE { mkexp $sloc (Erecord (List.rev $2)) }
  | LBRACE simple_expr WITH lbl_expr_list SEMI? RBRACE { mkexp $sloc (Ewith ($2, List.rev $4)) }
  | LBRACKETBAR expr_semi_list SEMI? BARRBRACKET { mkexp $sloc (Earray (List.rev $2)) }
  | LBRACKETBAR BARRBRACKET { mkexp $sloc (Earray []) }
  /* mlpp: */
  | LBRACKETPERCENT LIDENT seq_expr RBRACKET
      { mkexp $sloc (match $3.e with Econst (String s) -> Eextension ($2, s, span $sloc) | _ -> Equote ($2, $3, span $sloc)) }
  | simple_expr DOT label_longident { mkexp $sloc (Efield ($1, $3)) }
  /* M.(e): M's names in e */
  | mod_longident DOT LPAREN seq_expr RPAREN { mkexp $sloc (Eopen ($1, $4)) }
  | val_longident { mkexp $sloc (Eident $1) }
  | PREFIXOP simple_expr { mkexp $sloc (Eapply (ident $sloc $1, [ $2 ])) }
  | LPAREN seq_expr COLON core_type RPAREN { mkexp $sloc (Econstraint ($2, $4)) }
  /* e :> t, the identity: its types are objects, all one (Scope's object_d) */
  | LPAREN seq_expr COLONGREATER core_type RPAREN { $2 }
  | LPAREN seq_expr COLON core_type COLONGREATER core_type RPAREN { mkexp $sloc (Econstraint ($2, $4)) }
  | simple_expr DOT LPAREN seq_expr RPAREN { array_op $sloc "Array" "get" [ $1; $4 ] }
  | simple_expr DOT LBRACKET seq_expr RBRACKET { array_op $sloc "String" "get" [ $1; $4 ] }
;
/* an argument, labeled or not: ~x:e, ~x */
argument:
  | simple_expr { $1 }
  | LABEL simple_expr { mkexp $sloc (Elabel ($1, $2)) }
  | TILDE LIDENT { mkexp $sloc (Elabel ($2, ident $sloc $2)) }
;
expr_comma_list:
  | expr_comma_list COMMA expr { $3 :: $1 }
  | expr COMMA expr { [ $3; $1 ] }
;
expr_semi_list:
  | expr { [ $1 ] }
  | expr_semi_list SEMI expr { $3 :: $1 }
;
lbl_expr_list:
  | lbl_expr { [ $1 ] }
  | lbl_expr_list SEMI lbl_expr { $3 :: $1 }
;
/* l = e, or l alone: the variable l */
lbl_expr:
  | label_longident EQUAL expr { ($1, $3) }
  | label_longident { ($1, ident $sloc (last $1)) }
;
fun_def:
  | MINUSGREATER seq_expr { $2 }
  | parameter fun_def { mkfun $sloc $1 $2 }
;
/* a function's parameter, labeled or not: ~x, ~(x : t), ~x:p */
parameter:
  | simple_pattern { $1 }
  | TILDE LIDENT { mkpat $sloc (Plabel ($2, mkpat $sloc (Pvar $2))) }
  | TILDE LPAREN LIDENT COLON core_type RPAREN { mkpat $sloc (Plabel ($3, mkpat $sloc (Pconstraint (mkpat $sloc (Pvar $3), $5)))) }
  | LABEL simple_pattern { mkpat $sloc (Plabel ($1, $2)) }
;
let_binding:
  | val_ident fun_binding { (mkpat $sloc (Pvar $1), $2) }
  | pattern EQUAL seq_expr { ($1, $3) }
;
fun_binding:
  | EQUAL seq_expr { $2 }
  | parameter fun_binding { mkfun $sloc $1 $2 }
  | COLON core_type EQUAL seq_expr { mkexp $sloc (Econstraint ($4, $2)) }
;
match_cases:
  | pattern match_action { [ let g, e = $2 in ($1, g, e) ] }
  | match_cases BAR pattern match_action { (let g, e = $4 in ($3, g, e)) :: $1 }
;
match_action:
  | MINUSGREATER seq_expr { (None, $2) }
  | WHEN seq_expr MINUSGREATER seq_expr { (Some $2, $4) }
;

/* patterns */

pattern:
  | simple_pattern { $1 }
  | constr_longident pattern %prec prec_constr_appl { mkpat $sloc (Pconstruct ($1, Some $2)) }
  | pattern COLONCOLON pattern { mkpat $sloc (Pconstruct ([ "::" ], Some (mkpat $sloc (Ptuple [ $1; $3 ])))) }
  | pattern_comma_list { mkpat $sloc (Ptuple (List.rev $1)) }
  | pattern AS val_ident { mkpat $sloc (Palias ($1, $3)) }
  | pattern BAR pattern { mkpat $sloc (Por ($1, $3)) }
  /* a match's | exception E -> (mkmatch) */
  | EXCEPTION pattern %prec prec_constr_appl { mkpat $sloc (Pexception $2) }
;
simple_pattern:
  | signed_constant { mkpat $sloc (Pconst $1) }
  | CHAR DOTDOT CHAR { mkpat $sloc (Prange ($1, $3)) }
  | constr_longident { mkpat $sloc (Pconstruct ($1, None)) }
  | LBRACE lbl_pattern_list SEMI? RBRACE { mkpat $sloc (Precord (List.rev $2)) }
  /* { l = p; _ }: the other fields, which a record pattern never needed */
  | LBRACE lbl_pattern_list SEMI UNDERSCORE SEMI? RBRACE { mkpat $sloc (Precord (List.rev $2)) }
  | val_ident { mkpat $sloc (Pvar $1) }
  | UNDERSCORE { mkpat $sloc Pany }
  /* mlpp: a [%bits] pattern's span has the parentheses */
  | LPAREN pattern RPAREN { match $2.p with Pextension (n, s, _) -> mkpat $sloc (Pextension (n, s, span $sloc)) | _ -> $2 }
  | LPAREN pattern COLON core_type RPAREN { mkpat $sloc (Pconstraint ($2, $4)) }
  | LBRACKET pattern_semi_list SEMI? RBRACKET { mkpatlist $sloc (List.rev $2) }
  /* mlpp: */
  | LBRACKETPERCENT LIDENT STRING RBRACKET { mkpat $sloc (Pextension ($2, $3, span $sloc)) }
  | LBRACKETPERCENT LIDENT COLON core_type RBRACKET { if $2 <> "using" then raise Parsing.Parse_error; mkpat $sloc (Pusing ($4, span $sloc)) }
;
pattern_comma_list:
  | pattern_comma_list COMMA pattern { $3 :: $1 }
  | pattern COMMA pattern { [ $3; $1 ] }
;
pattern_semi_list:
  | pattern { [ $1 ] }
  | pattern_semi_list SEMI pattern { $3 :: $1 }
;
lbl_pattern_list:
  | lbl_pattern { [ $1 ] }
  | lbl_pattern_list SEMI lbl_pattern { $3 :: $1 }
;
/* l = p, or l alone: the variable l */
lbl_pattern:
  | label_longident EQUAL pattern { ($1, $3) }
  | label_longident { ($1, mkpat $sloc (Pvar (last $1))) }
;

/* types */

type_declarations:
  | separated_nonempty_list(AND, type_declaration) { $1 }
;
type_declaration:
  | type_parameters LIDENT type_kind
      { let kind, manifest = $3 in
        { tname = $2; tparams = $1; tkind = kind; tmanifest = manifest; tloc = line $sloc; tspan = span $loc($3); tattrs = [] } }
;
type_kind:
  | /* empty */ { (Abstract, None) }
  | EQUAL constructor_declarations { (Variant $2, None) }
  | EQUAL BAR constructor_declarations { (Variant $3, None) }
  | EQUAL LBRACE label_declarations SEMI? RBRACE { (Record (List.rev $3), None) }
  /* mlpp: type t = [%mli], the .mli's definition */
  | EQUAL LBRACKETPERCENT LIDENT RBRACKET { if $3 <> "mli" then raise Parsing.Parse_error; (Hole, None) }
  | EQUAL core_type { (Abstract, Some $2) }
  | EQUAL core_type EQUAL BAR? constructor_declarations { (Variant $5, Some $2) }
  | EQUAL core_type EQUAL LBRACE label_declarations SEMI? RBRACE { (Record (List.rev $5), Some $2) }
;
type_parameters:
  | /* empty */ { [] }
  | type_parameter { [ $1 ] }
  | LPAREN separated_nonempty_list(COMMA, type_parameter) RPAREN { $2 }
;
type_parameter:
  | QUOTE ident { $2 }
;
constructor_declarations:
  | separated_nonempty_list(BAR, constructor_declaration) { $1 }
;
constructor_declaration:
  | constr_ident constructor_arguments { ($1, $2) }
;
constructor_arguments:
  | /* empty */ { [] }
  | OF separated_nonempty_list(STAR, simple_core_type) { $2 }
  /* C of { l : t; ... }: an inline record */
  | OF LBRACE label_declarations SEMI? RBRACE { [ Trecord (List.rev $3) ] }
;
label_declarations:
  | label_declaration { [ $1 ] }
  | label_declarations SEMI label_declaration { $3 :: $1 }
;
label_declaration:
  | boption(MUTABLE) LIDENT COLON core_type { ($2, $1, $4) }
;
core_type:
  | simple_core_type { $1 }
  | core_type MINUSGREATER core_type { Tarrow ($1, $3) }
  /* x:t -> ...: a labeled argument's; a function's in parentheses */
  | LIDENT COLON label_domain MINUSGREATER core_type { Tarrow (Tlabel ($1, $3), $5) }
  | core_type_tuple { Ttuple (List.rev $1) }
;
label_domain:
  | simple_core_type { $1 }
  | core_type_tuple { Ttuple (List.rev $1) }
;
simple_core_type:
  | QUOTE ident { Tvar $2 }
  | UNDERSCORE { Tvar "_" }
  | type_longident { Tconstr ($1, []) }
  | simple_core_type type_longident { Tconstr ($2, [ $1 ]) }
  | LPAREN core_type_comma_list RPAREN type_longident { Tconstr ($4, List.rev $2) }
  | LPAREN core_type RPAREN { $2 }
  | LESS separated_list(SEMI, object_field) GREATER { Tconstr ([ "< .. >" ], []) }
  /* mlpp: */
  | LBRACKETPERCENT LIDENT COLON core_type RBRACKET { if $2 <> "using" then raise Parsing.Parse_error; Tusing ($4, span $sloc) }
;
/* < Cap.stdout; caps; .. >: an object type's methods or the types it
 * includes, and the others (..); all object types are one (Scope) */
object_field:
  | type_longident { () }
  | DOTDOT { () }
;
core_type_tuple:
  | simple_core_type STAR simple_core_type { [ $3; $1 ] }
  | core_type_tuple STAR simple_core_type { $3 :: $1 }
;
core_type_comma_list:
  | core_type COMMA core_type { [ $3; $1 ] }
  | core_type_comma_list COMMA core_type { $3 :: $1 }
;

/* names */

ident:
  | UIDENT { $1 }
  | LIDENT { $1 }
;
mod_longident:
  | UIDENT { [ $1 ] }
  | mod_longident DOT UIDENT { $1 @ [ $3 ] }
;
val_ident:
  | LIDENT { $1 }
  | LPAREN operator RPAREN { $2 }
  | LPAREN LETOP RPAREN { $2 }
;
operator:
  | PREFIXOP { $1 } | INFIXOP0 { $1 } | INFIXOP1 { $1 } | INFIXOP2 { $1 } | INFIXOP3 { $1 } | INFIXOP4 { $1 }
  | SUBTRACTIVE { $1 } | STAR { "*" } | EQUAL { "=" } | LESS { "<" } | GREATER { ">" } | OR { "or" }
  | BARBAR { "||" } | AMPERSAND { "&" } | AMPERAMPER { "&&" } | COLONEQUAL { ":=" }
;
type_longident:
  | LIDENT { [ $1 ] }
  | mod_longident DOT LIDENT { $1 @ [ $3 ] }
;
constr_ident:
  | UIDENT { $1 }
  | LBRACKET RBRACKET { "[]" }
  | LPAREN RPAREN { "()" }
  | COLONCOLON { "::" }
  | FALSE { "false" }
  | TRUE { "true" }
;
constr_longident:
  | mod_longident { $1 }
  | LBRACKET RBRACKET { [ "[]" ] }
  | LPAREN RPAREN { [ "()" ] }
  | FALSE { [ "false" ] }
  | TRUE { [ "true" ] }
;
label_longident:
  | LIDENT { [ $1 ] }
  | mod_longident DOT LIDENT { $1 @ [ $3 ] }
;
val_longident:
  | val_ident { [ $1 ] }
  | mod_longident DOT val_ident { $1 @ [ $3 ] }
;
constant:
  | INT { Int $1 }
  | CHAR { Char $1 }
  | STRING { String $1 }
  | FLOAT { Float $1 }
  | INT32 { Int32 $1 }
  | INT64 { Int64 $1 }
;
signed_constant:
  | constant { $1 }
  | SUBTRACTIVE INT { Int (- $2) }
  | SUBTRACTIVE FLOAT { Float ("-" ^ $2) }
  | SUBTRACTIVE INT32 { Int32 ("-" ^ $2) }
  | SUBTRACTIVE INT64 { Int64 ("-" ^ $2) }
;
rec_flag:
  | /* empty */ { Nonrec }
  | REC { Rec }
;
direction_flag:
  | TO { Upto }
  | DOWNTO { Downto }
;
%%
