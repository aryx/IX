/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* The grammar: awkgram.y's, rule for rule, its actions making Ast's
 * trees. awk's syntax is not LALR(1) as written (an expression after
 * another is their concatenation, a > after print's arguments a file,
 * a newline ends a statement or not): awkgram.y says it with
 * precedences and leaves 42 conflicts to yacc's choice, a shift before
 * a reduction and the earlier of two rules. They are left so here, for
 * menhir and for mini-yacc, which choose the same; so there are a
 * pattern and a ppattern (print's: no comparison, no pipe), alike.
 * (Of awkgram.y's precedences, those that decide nothing are not here:
 * a statement's words, the : of ?:.)
 *
 * What the C does in the middle of a rule is at the end of a rule of
 * its own (for_head, while_head, func_head: a loop or a function is
 * entered before its body is read), and a regular expression is one
 * token (Lexer). */
%{
open Ast

(* an action's refusal: the context shown ends with the rule's text *)
let error ((_ : Lexing.position), (last : Lexing.position)) msg =
  Scope.error_end := Some last.pos_cnum;
  raise (Cell.Syntax msg)

(* $0 *)
let record = Field_of (Const Cell.zero)

(* a condition: an expression that is not already true or false is
 * compared with the empty constant (as a number if it is one) *)
let notnull e =
  match e with
  | Compare _ | Or _ | And _ | Not _ -> e
  | _ -> Compare (Ne, e, Const Cell.null)

(* a name used as an array is one from now on *)
let makearr loc e =
  (match e with
   | Var ({ v = Function _; _ } as c) -> error loc (Printf.sprintf "%s is a function, not an array" c.name)
   | Var c -> ignore (Cell.array c)
   | _ -> ());
  e

(* e ~ x: a constant x is compiled now (a number's text, as written) *)
let regex_of e =
  match e with
  | Const { v = Scalar v; _ } -> Static (Re.compile v.s)
  | _ -> Dynamic e

let offset ((first : Lexing.position), (_ : Lexing.position)) = first.pos_cnum

let set_function_name loc (c : cell) =
  (match c.v with
   | Array _ -> error loc (Printf.sprintf "%s is an array, not a function" c.name)
   | Function _ -> error loc (Printf.sprintf "you can't define function %s more than once" c.name)
   | Scalar _ -> ());
  Scope.function_name := Some c.name;
  c

let define loc (c : cell) params body =
  (match c.v with Array _ -> error loc (Printf.sprintf "`%s' is an array name and a function name" c.name) | _ -> ());
  if List.mem c.name params then error loc (Printf.sprintf "`%s' is both function name and argument name" c.name);
  c.v <- Function { params = List.length params; body }
%}

%token <Ast.cell> VAR IVAR CALL NUMBER STRING
%token <int> ARG
%token <Ast.builtin> BLTIN
%token <Ast.assign> ASGNOP
/* !~ */
%token <bool> MATCHOP
/* gsub */
%token <bool> SUBOP
%token <string> REGEXPR
%token XBEGIN XEND NL COMMA LBRACE RBRACE LPAREN RPAREN LBRACKET RBRACKET SEMI BAR
%token AND BOR NOT APPEND EQ GE GT LE LT NE IN
%token BREAK CLOSE CONTINUE DELETE DO EXIT FOR FUNC GETLINE IF INDEX MATCHFCN NEXT NEXTFILE
%token PLUS MINUS STAR SLASH PERCENT POWER PRINT PRINTF SPRINTF ELSE INCR DECR VARNF
%token RETURN SPLIT SUBSTR WHILE QUESTION COLON INDIRECT EOF
/* a character of no rule */
%token OTHER

%right ASGNOP
%right QUESTION
%left BOR
%left AND
%left GETLINE
%nonassoc EQ GE GT LE LT NE MATCHOP IN BAR
%left ARG BLTIN CALL
%left SUBOP INDEX MATCHFCN NUMBER
%left SPLIT SPRINTF STRING SUBSTR
%left VAR VARNF IVAR LPAREN
%left CAT
%left PLUS MINUS
%left STAR SLASH PERCENT
%left NOT UMINUS
%right POWER
%right DECR INCR
%left INDIRECT

%start program
%type <Ast.program> program
%type <Ast.expr> pattern ppattern term var varname re
%type <Ast.stmt> stmt simple_stmt

%%

program:
  | pas EOF { { begins = !Scope.begins; rules = $1; ends = !Scope.ends } }
  ;

and_: AND { } | and_ NL { };
bor: BOR { } | bor NL { };
comma: COMMA { } | comma NL { };
do_: DO { } | do_ NL { };
else_: ELSE { } | else_ NL { };
lbrace: LBRACE { } | lbrace NL { };
nl: NL { } | nl NL { };
opt_nl: /* empty */ { } | nl { };
opt_pst: /* empty */ { } | pst { };
pst: NL { } | SEMI { } | pst NL { } | pst SEMI { };
rbrace: RBRACE { } | rbrace NL { };
rparen: RPAREN { } | rparen NL { };
st: nl { } | SEMI opt_nl { };

/* a loop's header: the loop is entered before its body is read */
for_head:
  | FOR LPAREN opt_simple_stmt SEMI opt_nl pattern SEMI opt_nl opt_simple_stmt rparen
      { incr Scope.loops; fun body -> For ($3, Some (notnull $6), $9, body) }
  | FOR LPAREN opt_simple_stmt SEMI SEMI opt_nl opt_simple_stmt rparen
      { incr Scope.loops; fun body -> For ($3, None, $7, body) }
  | FOR LPAREN varname IN varname rparen
      { incr Scope.loops; fun body -> For_in ($3, makearr $sloc $5, body) }
  ;

while_head: WHILE LPAREN pattern rparen { incr Scope.loops; notnull $3 };

do_head: do_ { incr Scope.loops };

funcname:
  | VAR { set_function_name $sloc $1 }
  | CALL { set_function_name $sloc $1 }
  ;

func_head: FUNC funcname LPAREN varlist rparen { Scope.in_function := true; ($2, $4) };

if_: IF LPAREN pattern rparen { notnull $3 };

opt_simple_stmt:
  | /* empty */ { None }
  | simple_stmt { Some $1 }
  ;

pas:
  | opt_pst { [] }
  | opt_pst pa_stats opt_pst { $2 }
  ;

pa_pat: pattern { notnull $1 };

pa_stat:
  | pa_pat { [ When ($1, Print ([ record ], None)) ] }
  | pa_pat lbrace stmtlist RBRACE { [ When ($1, Block $3) ] }
  | pa_pat COMMA pa_pat { [ Range ($1, $3, Print ([ record ], None), ref false) ] }
  | pa_pat COMMA pa_pat lbrace stmtlist RBRACE { [ Range ($1, $3, Block $5, ref false) ] }
  | lbrace stmtlist RBRACE { [ Always (Block $2) ] }
  | XBEGIN lbrace stmtlist RBRACE { Scope.begins := !Scope.begins @ $3; [] }
  | XEND lbrace stmtlist RBRACE { Scope.ends := !Scope.ends @ $3; [] }
  | func_head lbrace stmtlist RBRACE
      { let name, params = $1 in
        Scope.in_function := false; Scope.function_name := None;
        define $sloc name params (Block $3); [] }
  ;

pa_stats:
  | pa_stat { $1 }
  | pa_stats opt_pst pa_stat { $1 @ $3 }
  ;

patlist:
  | pattern { [ $1 ] }
  | patlist comma pattern { $1 @ [ $3 ] }
  ;

ppattern:
  | var ASGNOP ppattern { Assign ($2, $1, $3) }
  | ppattern QUESTION ppattern COLON ppattern %prec QUESTION { Cond (notnull $1, $3, $5) }
  | ppattern bor ppattern %prec BOR { Or (notnull $1, notnull $3) }
  | ppattern and_ ppattern %prec AND { And (notnull $1, notnull $3) }
  | ppattern MATCHOP REGEXPR { Match ($2, $1, Static (Re.compile $3)) }
  | ppattern MATCHOP ppattern { Match ($2, $1, regex_of $3) }
  | ppattern IN varname { In ([ $1 ], makearr $sloc $3) }
  | LPAREN plist RPAREN IN varname { In ($2, makearr $sloc $5) }
  | ppattern term %prec CAT { Cat ($1, $2) }
  | re { $1 }
  | term { $1 }
  ;

pattern:
  | var ASGNOP pattern { Assign ($2, $1, $3) }
  | pattern QUESTION pattern COLON pattern %prec QUESTION { Cond (notnull $1, $3, $5) }
  | pattern bor pattern %prec BOR { Or (notnull $1, notnull $3) }
  | pattern and_ pattern %prec AND { And (notnull $1, notnull $3) }
  | pattern EQ pattern { Compare (Eq, $1, $3) }
  | pattern GE pattern { Compare (Ge, $1, $3) }
  | pattern GT pattern { Compare (Gt, $1, $3) }
  | pattern LE pattern { Compare (Le, $1, $3) }
  | pattern LT pattern { Compare (Lt, $1, $3) }
  | pattern NE pattern { Compare (Ne, $1, $3) }
  | pattern MATCHOP REGEXPR { Match ($2, $1, Static (Re.compile $3)) }
  | pattern MATCHOP pattern { Match ($2, $1, regex_of $3) }
  | pattern IN varname { In ([ $1 ], makearr $sloc $3) }
  | LPAREN plist RPAREN IN varname { In ($2, makearr $sloc $5) }
  | pattern BAR GETLINE var { Getline (Some $4, Some (From_command, $1)) }
  | pattern BAR GETLINE { Getline (None, Some (From_command, $1)) }
  | pattern term %prec CAT { Cat ($1, $2) }
  | re { $1 }
  | term { $1 }
  ;

plist:
  | pattern comma pattern { [ $1; $3 ] }
  | plist comma pattern { $1 @ [ $3 ] }
  ;

pplist:
  | ppattern { [ $1 ] }
  | pplist comma ppattern { $1 @ [ $3 ] }
  ;

prarg:
  | /* empty */ { [ record ] }
  | pplist { $1 }
  | LPAREN plist RPAREN { $2 }
  ;

print:
  | PRINT { fun args out -> Print (args, out) }
  | PRINTF { fun args out -> Printf (args, out) }
  ;

/* /re/ alone: does the record match */
re:
  | REGEXPR { Match (false, record, Static (Re.compile $1)) }
  | NOT re { Not (notnull $2) }
  ;

simple_stmt:
  | print prarg BAR term { $1 $2 (Some (To_command, $4)) }
  | print prarg APPEND term { $1 $2 (Some (Append, $4)) }
  | print prarg GT term { $1 $2 (Some (To_file, $4)) }
  | print prarg { $1 $2 None }
  | DELETE varname LBRACKET patlist RBRACKET { Delete (makearr $sloc $2, Some $4) }
  | DELETE varname { Delete (makearr $sloc $2, None) }
  | pattern { Expr $1 }
  ;

stmt:
  | BREAK st { if !Scope.loops = 0 then error $sloc "break illegal outside of loops"; Break }
  | CLOSE pattern st { At (offset $sloc, Close $2) }
  | CONTINUE st { if !Scope.loops = 0 then error $sloc "continue illegal outside of loops"; Continue }
  | do_head stmt WHILE LPAREN pattern RPAREN st { decr Scope.loops; Do ($2, notnull $5) }
  | EXIT pattern st { At (offset $sloc, Exit (Some $2)) }
  | EXIT st { Exit None }
  | for_head stmt { decr Scope.loops; $1 $2 }
  | if_ stmt else_ stmt { If ($1, $2, Some $4) }
  | if_ stmt { If ($1, $2, None) }
  | lbrace stmtlist rbrace { Block $2 }
  | NEXT st { if !Scope.in_function then error $sloc "next is illegal inside a function"; Next }
  | NEXTFILE st { if !Scope.in_function then error $sloc "nextfile is illegal inside a function"; Nextfile }
  | RETURN pattern st { At (offset $sloc, Return (Some $2)) }
  | RETURN st { Return None }
  | simple_stmt st { At (offset $sloc, $1) }
  | while_head stmt { decr Scope.loops; While ($1, $2) }
  | SEMI opt_nl { Block [] }
  ;

stmtlist:
  | stmt { [ $1 ] }
  | stmtlist stmt { $1 @ [ $2 ] }
  ;

term:
  | term PLUS term { Arith (Add, $1, $3) }
  | term MINUS term { Arith (Sub_, $1, $3) }
  | term STAR term { Arith (Mul, $1, $3) }
  | term SLASH term { Arith (Div, $1, $3) }
  | term PERCENT term { Arith (Mod, $1, $3) }
  | term POWER term { Arith (Pow, $1, $3) }
  | MINUS term %prec UMINUS { Neg $2 }
  | PLUS term %prec UMINUS { $2 }
  | NOT term %prec UMINUS { Not (notnull $2) }
  | BLTIN LPAREN RPAREN { Builtin ($1, []) }
  | BLTIN LPAREN patlist RPAREN { Builtin ($1, $3) }
  | BLTIN { Builtin ($1, []) }
  | CALL LPAREN RPAREN { Call ($1, []) }
  | CALL LPAREN patlist RPAREN { Call ($1, $3) }
  | DECR var { Step ($2, -1., true) }
  | INCR var { Step ($2, 1., true) }
  | var DECR { Step ($1, -1., false) }
  | var INCR { Step ($1, 1., false) }
  | GETLINE var LT term { Getline (Some $2, Some (From_file, $4)) }
  | GETLINE LT term { Getline (None, Some (From_file, $3)) }
  | GETLINE var { Getline (Some $2, None) }
  | GETLINE { Getline (None, None) }
  | INDEX LPAREN pattern comma pattern RPAREN { Index ($3, $5) }
  | INDEX LPAREN pattern comma REGEXPR RPAREN { ignore $3; ignore $5; error $sloc "index() doesn't permit regular expressions" }
  | LPAREN pattern RPAREN { $2 }
  | MATCHFCN LPAREN pattern comma REGEXPR RPAREN { Match_fn ($3, Static (Re.compile $5)) }
  | MATCHFCN LPAREN pattern comma pattern RPAREN { Match_fn ($3, regex_of $5) }
  | NUMBER { Const $1 }
  | SPLIT LPAREN pattern comma varname comma pattern RPAREN { Split ($3, makearr $sloc $5, Sep_string $7) }
  | SPLIT LPAREN pattern comma varname comma REGEXPR RPAREN { Split ($3, makearr $sloc $5, Sep_regex (Re.compile $7)) }
  | SPLIT LPAREN pattern comma varname RPAREN { Split ($3, makearr $sloc $5, Default) }
  | SPRINTF LPAREN patlist RPAREN { Sprintf $3 }
  | STRING { Const $1 }
  | SUBOP LPAREN REGEXPR comma pattern RPAREN { Sub ($1, Static (Re.compile $3), $5, record) }
  | SUBOP LPAREN pattern comma pattern RPAREN { Sub ($1, regex_of $3, $5, record) }
  | SUBOP LPAREN REGEXPR comma pattern comma var RPAREN { Sub ($1, Static (Re.compile $3), $5, $7) }
  | SUBOP LPAREN pattern comma pattern comma var RPAREN { Sub ($1, regex_of $3, $5, $7) }
  | SUBSTR LPAREN pattern comma pattern comma pattern RPAREN { Substr ($3, $5, Some $7) }
  | SUBSTR LPAREN pattern comma pattern RPAREN { Substr ($3, $5, None) }
  | var { $1 }
  ;

var:
  | varname { $1 }
  | varname LBRACKET patlist RBRACKET { Elem (makearr $sloc $1, $3) }
  | IVAR { Field_of (Var $1) }
  | INDIRECT term { Field_of $2 }
  ;

varlist:
  | /* nothing */ { Scope.params := []; [] }
  | VAR { Scope.params := [ $1.name ]; !Scope.params }
  | varlist comma VAR
      { if List.mem $3.name $1 then error $sloc (Printf.sprintf "duplicate argument %s" $3.name);
        Scope.params := $1 @ [ $3.name ]; !Scope.params }
  ;

varname:
  | VAR { Var $1 }
  | ARG { Arg $1 }
  | VARNF { Nf }
  ;
