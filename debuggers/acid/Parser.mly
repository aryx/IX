%{
(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* acid's grammar (principia's dbg.y): a top-level statement run as
 * soon as it is read, by the grammar's own action (acid's bigstmnt's:
 * a parse that stopped after each would want the next token first);
 * an error in it ends the parse, and the caller starts another. Its
 * precedences as dbg.y's, a format (x\D) binding looser than the
 * operators *)

open Ast

let con i = Const { kind = Int i; fmt = 'W'; comt = None }

let name_of = function
  | Name s -> s
  | _ -> raise Parsing.Parse_error

let param_of = function
  | Name s -> { pname = s; by_name = false }
  | Indm (Name s) -> { pname = s; by_name = true }
  | _ -> raise Parsing.Parse_error
%}

%token <string> ID
%token <int64> CONST
%token <float> FCONST
%token <string> STRING
%token <char> FMT
%token IF DO THEN ELSE WHILE LOOP HEAD TAIL APPEND DEFN RETURN LOCAL
%token COMPLEX WHAT DELETE EVAL BUILTIN
%token INDIR DEC INC LSH RSH LEQ GEQ EQ NEQ ANDAND OROR
%token LBRACE RBRACE LPAREN RPAREN LBRACK RBRACK SEMI COLON COMMA TILDE
%token STAR AT CARET PERCENT BANG PLUS MINUS AMP BAR ASSIGN LT GT SLASH DOT
%token EOF

%left SEMI
%right ASSIGN
%left FMT
%left OROR
%left ANDAND
%left BAR
%left CARET
%left AMP
%left EQ NEQ
%left LT GT LEQ GEQ
%left LSH RSH
%left PLUS MINUS
%left STAR SLASH PERCENT
%right DEC INC INDIR DOT LBRACK LPAREN
%nonassoc ELSE

%start program
%type <unit> program

%%

program:
  | prog EOF { () }
  ;

prog:
  | { () }
  | prog bigstmnt { Eval.toplevel $2; (match $2 with Stmt _ -> !Eval.ran () | _ -> ()) }
  ;

bigstmnt:
  | stmnt { Stmt $1 }
  | DEFN ID LPAREN args RPAREN zsemi LBRACE slist RBRACE { Defn ($2, List.map param_of $4, List.rev $8) }
  | DEFN ID { Undefn $2 }
  | COMPLEX ID LBRACE members RBRACE SEMI { Aggr ($2, List.rev $4) }
  ;

stmnt:
  | zexpr SEMI { Expr $1 }
  | LBRACE slist RBRACE { Block (List.rev $2) }
  | IF expr THEN stmnt { If ($2, $4, None) }
  | IF expr THEN stmnt ELSE stmnt { If ($2, $4, Some $6) }
  | LOOP expr COMMA expr DO stmnt { Loop ($2, $4, $6) }
  | WHILE expr DO stmnt { While ($2, $4) }
  | RETURN expr SEMI { Return $2 }
  | LOCAL idlist { Local $2 }     /* (the last first, as acid's chain: whatis prints them so) */
  | COMPLEX ID name SEMI { Complex ($2, $3) }
  ;

slist:
  | stmnt { [ $1 ] }
  | slist stmnt { $2 :: $1 }
  ;

members:
  | member { $1 }
  | members member { $2 @ $1 }
  ;

/* (the members in reverse: members' List.rev puts them back) */
member:
  | CONST CONST ID SEMI { [ { mfmt = Char.chr (Int64.to_int $1); moffset = Int64.to_int $2; mname = $3; mtype = None } ] }
  | CONST ID CONST ID SEMI { [ { mfmt = Char.chr (Int64.to_int $1); moffset = Int64.to_int $3; mname = $4; mtype = Some $2 } ] }
  | ID CONST ID SEMI { [ { mfmt = 'a'; moffset = Int64.to_int $2; mname = $3; mtype = Some $1 } ] }
  | LBRACE members RBRACE SEMI { $2 }
  ;

expr:
  | castexpr { $1 }
  | expr STAR expr { Bin (Mul, $1, $3) }
  | expr SLASH expr { Bin (Div, $1, $3) }
  | expr PERCENT expr { Bin (Mod, $1, $3) }
  | expr PLUS expr { Bin (Add, $1, $3) }
  | expr MINUS expr { Bin (Sub, $1, $3) }
  | expr RSH expr { Bin (Rsh, $1, $3) }
  | expr LSH expr { Bin (Lsh, $1, $3) }
  | expr LT expr { Bin (Lt, $1, $3) }
  | expr GT expr { Bin (Gt, $1, $3) }
  | expr LEQ expr { Bin (Leq, $1, $3) }
  | expr GEQ expr { Bin (Geq, $1, $3) }
  | expr EQ expr { Bin (Eq, $1, $3) }
  | expr NEQ expr { Bin (Neq, $1, $3) }
  | expr AMP expr { Bin (Land, $1, $3) }
  | expr CARET expr { Bin (Xor, $1, $3) }
  | expr BAR expr { Bin (Lor, $1, $3) }
  | expr ANDAND expr { Cand ($1, $3) }
  | expr OROR expr { Cor ($1, $3) }
  | expr ASSIGN expr { Assign ($1, $3) }
  | expr FMT { Fmt ($1, $2) }
  ;

castexpr:
  | monexpr { $1 }
  | LPAREN ID RPAREN monexpr { Cast ($2, $4) }
  ;

monexpr:
  | term { $1 }
  | STAR monexpr { Indm $2 }
  | AT monexpr { Indc $2 }
  | PLUS monexpr { Plus $2 }
  | MINUS monexpr { Bin (Sub, con 0L, $2) }
  | DEC monexpr { Predec $2 }
  | INC monexpr { Preinc $2 }
  | HEAD monexpr { Head $2 }
  | TAIL monexpr { Tail $2 }
  | APPEND monexpr COMMA monexpr { Append ($2, $4) }
  | DELETE monexpr COMMA monexpr { Delete ($2, $4) }
  | BANG monexpr { Not $2 }
  | TILDE monexpr { Bin (Xor, $2, con (-1L)) }
  | EVAL monexpr { Eval $2 }
  ;

term:
  | LPAREN expr RPAREN { $2 }
  | LBRACE args RBRACE { Construct $2 }
  | term LBRACK expr RBRACK { Index ($1, $3) }
  | term DEC { Postdec $1 }
  | term DOT ID { Dot ($1, $3) }
  | term INDIR ID { Dot (Indm $1, $3) }
  | term INC { Postinc $1 }
  | name LPAREN args RPAREN { Call (name_of $1, $3, false) }
  | BUILTIN name LPAREN args RPAREN { Call (name_of $2, $4, true) }
  | name { $1 }
  | CONST { con $1 }
  | FCONST { Const { kind = Float $1; fmt = 'f'; comt = None } }
  | STRING { Const { kind = String $1; fmt = 's'; comt = None } }
  | WHAT zname { What $2 }
  ;

/* (acid's args: empty ones dropped, as flatten drops them) */
args:
  | zexpr { match $1 with Some e -> [ e ] | None -> [] }
  | args COMMA zexpr { match $3 with Some e -> $1 @ [ e ] | None -> $1 }
  ;

zexpr:
  | { None }
  | expr { Some $1 }
  ;

name:
  | ID { Name $1 }
  | ID COLON name { Frame ($1, name_of $3) }
  ;

zname:
  | { None }
  | ID { Some $1 }
  ;

zsemi:
  | { () }
  | SEMI zsemi { () }
  ;

idlist:
  | ID { [ $1 ] }
  | idlist COMMA ID { $3 :: $1 }
  ;
