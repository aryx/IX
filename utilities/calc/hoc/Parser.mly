/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* The grammar: hoc.y's, a line at a time (yyparse returns at the end of
 * each line that has something to run), its actions making a tree
 * where the C's emit the stack machine's code. A definition is done
 * here, as the C's define: the name is a function from its header on.
 * The lists are menhir's standard rules, which mini-yacc reads too.
 *
 * hoc.y leaves its conflicts to yacc (a shift before a reduction); here
 * each is said, and the grammar has none:
 *  - a line that is an assignment is not printed, any other expression
 *    is: asgn and value, the two halves of expr;
 *  - a statement goes on as far as it can (in { x -1 }, one statement;
 *    return -1; x ++ y; an else with the nearest if): LOW, lower than
 *    what could follow. */
%{
open Ast

let error msg = raise (Symbol.Error msg)

(* a definition's name, from its header: what it had as its code is
 * kept until the body is read *)
let header (s : symbol) make =
  let old = match s.value with Func d | Proc d -> d | Undef | Var _ | Builtin _ -> { formals = []; body = Block [] } in
  s.value <- make old;
  Symbol.in_definition := true;
  s
%}

%token <float> NUMBER
%token <string> STRING
%token <Ast.symbol> VAR FUNCTION PROCEDURE
%token <float -> float> BLTIN
%token PRINT WHILE FOR IF ELSE FUNC PROC RETURN READ
%token ASSIGN ADDEQ SUBEQ MULEQ DIVEQ MODEQ
%token OR AND GT GE LT LE EQ NE PLUS MINUS STAR SLASH PERCENT NOT INC DEC CARET
%token LPAREN RPAREN LBRACE RBRACE COMMA SEMI NEWLINE EOF
/* a character of no rule */
%token OTHER

%nonassoc LOW
%nonassoc ELSE NUMBER VAR FUNCTION BLTIN READ LPAREN
%right ASSIGN
%left OR
%left AND
%left GT GE LT LE EQ NE
%left PLUS MINUS
%left STAR SLASH PERCENT
%left UNARYMINUS NOT INC DEC
%right CARET

%start line
%type <Ast.line> line

%%

line:
  | NEWLINE { Nothing }
  | defn NEWLINE { Nothing }
  | asgn NEWLINE { Run (Expr $1) }
  | value NEWLINE { Show $1 }
  | action NEWLINE { Run $1 }
  | EOF { End }
  ;

asgn: VAR assign expr %prec ASSIGN { Assign ($1, $2, $3) };

assign:
  | ASSIGN { Set } | ADDEQ { Add_to } | SUBEQ { Sub_to } | MULEQ { Mul_to } | DIVEQ { Div_to } | MODEQ { Mod_to }
  ;

stmt:
  | expr %prec LOW { Expr $1 }
  | action { $1 }
  ;

/* a statement that is not an expression */
action:
  | RETURN %prec LOW { if not !Symbol.in_definition then error "return used outside definition"; Return None }
  | RETURN expr %prec LOW { if not !Symbol.in_definition then error "return used outside definition"; Return (Some $2) }
  | PROCEDURE LPAREN separated_list(COMMA, expr) RPAREN { Call_proc ($1, $3) }
  | PRINT separated_nonempty_list(COMMA, item) { Print $2 }
  | WHILE LPAREN expr RPAREN stmt { While ($3, $5) }
  | FOR LPAREN expr SEMI expr SEMI expr RPAREN stmt { For ($3, $5, $7, $9) }
  | IF LPAREN expr RPAREN stmt %prec LOW { If ($3, $5, None) }
  | IF LPAREN expr RPAREN stmt ELSE stmt { If ($3, $5, Some $7) }
  | LBRACE in_braces* RBRACE { Block (List.concat $2) }
  ;

in_braces:
  | NEWLINE { [] }
  | stmt { [ $1 ] }
  ;

expr:
  | asgn { $1 }
  | value { $1 }
  ;

value:
  | NUMBER { Number $1 }
  | VAR %prec LOW { Variable $1 }
  | FUNCTION LPAREN separated_list(COMMA, expr) RPAREN { Call ($1, $3) }
  | READ LPAREN VAR RPAREN { Read $3 }
  | BLTIN LPAREN expr RPAREN { Apply ($1, $3) }
  | LPAREN expr RPAREN { $2 }
  | expr PLUS expr { Binary ($1, Add, $3) }
  | expr MINUS expr { Binary ($1, Sub, $3) }
  | expr STAR expr { Binary ($1, Mul, $3) }
  | expr SLASH expr { Binary ($1, Div, $3) }
  | expr PERCENT expr { Binary ($1, Mod, $3) }
  | expr CARET expr { Binary ($1, Power, $3) }
  | MINUS expr %prec UNARYMINUS { Negate $2 }
  | expr GT expr { Binary ($1, Gt, $3) }
  | expr GE expr { Binary ($1, Ge, $3) }
  | expr LT expr { Binary ($1, Lt, $3) }
  | expr LE expr { Binary ($1, Le, $3) }
  | expr EQ expr { Binary ($1, Eq, $3) }
  | expr NE expr { Binary ($1, Ne, $3) }
  | expr AND expr { Binary ($1, And, $3) }
  | expr OR expr { Binary ($1, Or, $3) }
  | NOT expr { Not $2 }
  | INC VAR { Step ($2, 1., true) }
  | DEC VAR { Step ($2, -1., true) }
  | VAR INC { Step ($1, 1., false) }
  | VAR DEC { Step ($1, -1., false) }
  ;

item:
  | expr %prec LOW { Value $1 }
  | STRING { Text $1 }
  ;

defn:
  | FUNC funcname LPAREN formals RPAREN stmt { $2.value <- Func { formals = $4; body = $6 }; Symbol.in_definition := false }
  | PROC procname LPAREN formals RPAREN stmt { $2.value <- Proc { formals = $4; body = $6 }; Symbol.in_definition := false }
  ;

funcname: name { header $1 (fun d -> Func d) };
procname: name { header $1 (fun d -> Proc d) };

name: VAR { $1 } | FUNCTION { $1 } | PROCEDURE { $1 };

/* (not separated_list: hoc.y's takes f(a,) too) */
formals:
  | /* nothing */ { [] }
  | VAR { [ $1 ] }
  | VAR COMMA formals { $1 :: $3 }
  ;
