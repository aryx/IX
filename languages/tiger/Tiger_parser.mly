%{
(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* Tiger's grammar (Appel's Tiger Language Reference Manual), with
 * fork-tiger's exceptions; its precedences as fork-tiger's parser.mly
 * resolves the conflicts (the declarations' groups, `if then` without
 * its `else`, an lvalue's `[` against an array's construction). *)
open Tiger_ast

let pos () : pos =
  let p = Parsing.symbol_start_pos () in
  (p.Lexing.pos_lnum, p.Lexing.pos_cnum - p.Lexing.pos_bol + 1)

(* consecutive type and function declarations: one group each, which
 * may name each other *)
let rec group (ds : dec list) : dec list =
  match ds with
  | TypeDecs a :: TypeDecs b :: rest -> group (TypeDecs (a @ b) :: rest)
  | FunDecs a :: FunDecs b :: rest -> group (FunDecs (a @ b) :: rest)
  | d :: rest -> d :: group rest
  | [] -> []
%}

%token <string> ID
%token <int32> INT
%token <string> STRING
%token IF THEN ELSE END WHILE DO FOR TO BREAK
%token PLUS MINUS TIMES DIVIDE AND OR
%token EQ NEQ LT LE GT GE
%token FUNCTION VAR LET IN TYPE OF ARRAY NIL
%token ASSIGN COLON COMMA DOT SEMICOLON
%token LPAREN RPAREN LBRACK RBRACK LBRACE RBRACE
%token EXCEPTION TRY RAISE HANDLE
%token EOF

%right HANDLE LBRACK
%nonassoc DO OF THEN
%nonassoc ELSE
%nonassoc ASSIGN
%left OR
%left AND
%nonassoc EQ NEQ GT LT GE LE
%left PLUS MINUS
%left TIMES DIVIDE
%nonassoc UMINUS

%start program
%type <Tiger_ast.exp> program

%%

program:
    expr EOF { $1 }
  ;

expr:
    NIL { Nil (pos ()) }
  | INT { Int ($1, pos ()) }
  | STRING { String ($1, pos ()) }
  | lvalue { Var $1 }
  | MINUS expr %prec UMINUS { Op (Int (Int32.zero, pos ()), Minus, $2, pos ()) }
  | expr PLUS expr { Op ($1, Plus, $3, pos ()) }
  | expr MINUS expr { Op ($1, Minus, $3, pos ()) }
  | expr TIMES expr { Op ($1, Times, $3, pos ()) }
  | expr DIVIDE expr { Op ($1, Divide, $3, pos ()) }
  | expr EQ expr { Op ($1, Eq, $3, pos ()) }
  | expr NEQ expr { Op ($1, Neq, $3, pos ()) }
  | expr LT expr { Op ($1, Lt, $3, pos ()) }
  | expr LE expr { Op ($1, Le, $3, pos ()) }
  | expr GT expr { Op ($1, Gt, $3, pos ()) }
  | expr GE expr { Op ($1, Ge, $3, pos ()) }
  | expr AND expr { If ($1, $3, Some (Int (Int32.zero, pos ())), pos ()) }
  | expr OR expr { If ($1, Int (Int32.one, pos ()), Some $3, pos ()) }
  | ID LPAREN args RPAREN { Call ($1, $3, pos ()) }
  | ID LBRACE fields RBRACE { Record ($1, $3, pos ()) }
  | ID LBRACK expr RBRACK OF expr { Array ($1, $3, $6, pos ()) }
  | LPAREN seq RPAREN { match $2 with [ e ] -> e | l -> Seq (l, pos ()) }
  | lvalue ASSIGN expr { Assign ($1, $3, pos ()) }
  | IF expr THEN expr { If ($2, $4, None, pos ()) }
  | IF expr THEN expr ELSE expr { If ($2, $4, Some $6, pos ()) }
  | WHILE expr DO expr { While ($2, $4, pos ()) }
  | FOR ID ASSIGN expr TO expr DO expr { For ($2, $4, $6, $8, pos ()) }
  | BREAK { Break (pos ()) }
  | LET decs IN seq END { Let (group $2, (match $4 with [ e ] -> e | l -> Seq (l, pos ())), pos ()) }
  | TRY expr handlers { Try ($2, $3, pos ()) }
  | RAISE ID { Raise ($2, pos ()) }
  ;

lvalue:
    ID %prec LBRACK { Simple ($1, pos ()) }
  | ID LBRACK expr RBRACK { Subscript (Simple ($1, pos ()), $3, pos ()) }
  | lvalue DOT ID { Field ($1, $3, pos ()) }
  | lvalue LBRACK expr RBRACK { Subscript ($1, $3, pos ()) }
  ;

args:
    { [] }
  | args1 { $1 }
  ;
args1:
    expr { [ $1 ] }
  | expr COMMA args1 { $1 :: $3 }
  ;

fields:
    { [] }
  | fields1 { $1 }
  ;
fields1:
    ID EQ expr { [ ($1, $3, pos ()) ] }
  | ID EQ expr COMMA fields1 { ($1, $3, pos ()) :: $5 }
  ;

/* (empty: the unit, a sequence of none) */
seq:
    { [] }
  | seq1 { $1 }
  ;
seq1:
    expr { [ $1 ] }
  | expr SEMICOLON seq1 { $1 :: $3 }
  ;

handlers:
    handler %prec HANDLE { [ $1 ] }
  | handler handlers { $1 :: $2 }
  ;
handler:
    HANDLE ID expr END { ($2, $3, pos ()) }
  ;

decs:
    { [] }
  | dec decs { $1 :: $2 }
  ;
dec:
    TYPE ID EQ ty { TypeDecs [ ($2, $4, pos ()) ] }
  | VAR ID ASSIGN expr { VarDec ($2, None, $4, pos ()) }
  | VAR ID COLON ID ASSIGN expr { VarDec ($2, Some ($4, pos ()), $6, pos ()) }
  | FUNCTION ID LPAREN tyfields RPAREN EQ expr
      { FunDecs [ { fname = $2; params = $4; result = None; body = $7; fpos = pos () } ] }
  | FUNCTION ID LPAREN tyfields RPAREN COLON ID EQ expr
      { FunDecs [ { fname = $2; params = $4; result = Some ($7, pos ()); body = $9; fpos = pos () } ] }
  | EXCEPTION ID { ExnDec ($2, pos ()) }
  ;

ty:
    ID { NameTy ($1, pos ()) }
  | LBRACE tyfields RBRACE { RecordTy $2 }
  | ARRAY OF ID { ArrayTy ($3, pos ()) }
  ;

tyfields:
    { [] }
  | tyfields1 { $1 }
  ;
tyfields1:
    ID COLON ID { [ ($1, $3, pos ()) ] }
  | ID COLON ID COMMA tyfields1 { ($1, $3, pos ()) :: $5 }
  ;
