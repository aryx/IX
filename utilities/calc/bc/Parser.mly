/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* The grammar: bc.y's, a statement or a definition at a time, each
 * rule's value the dc commands it compiles to (the C's bundles: here
 * strings put end to end). a + b is "la lb +"; a = e is "e dsa" then
 * "s." to drop the copy; an expression alone is printed: "ps.".
 *
 * The rules crs and blev are empty: bc.y's CRS and BLEV, there for
 * what they do when the parser passes (a register taken for the body
 * that follows; the body ended). The for loop is Plan 9's bc.y's:
 * principia's has it left out, with its if and while (bugs/goken.md). */
%{
open State
%}

%token <string> LETTER EQOP QSTR
%token <char> DIGIT
%token PRINT IF WHILE FOR SQRT RETURN BREAK DEFINE SCALE BASE OBASE FFF AUTO LENGTH
%token DOT INCR DECR EQ LE GE NE STAR PERCENT CARET PLUS MINUS SLASH ASSIGN LT GT
%token LPAREN RPAREN LBRACE RBRACE LBRACKET RBRACKET COMMA SEMI NEWLINE TILDE QUESTION UNDERSCORE EOF
/* a word that is no keyword, a character of no rule */
%token ERROR

%right ASSIGN EQOP
%left PLUS MINUS
%left STAR SLASH PERCENT
%right CARET

%start stuff
%type <unit> stuff
%type <string> e ase nase stat stat1 pstat slist re cons constant crs def fprefix lora cargs eora

%%

stuff:
  | pstat tail { output $1 }
  | def dargs RPAREN LBRACE dlist slist RBRACE
      { conout (!pre ^ $6 ^ !post ^ "0" ^ number !lev ^ "Q") $1;
        rcrs := !crs;
        output "";
        lev := 0; bindx := 0 }
  | EOF { raise Quit }
  ;

dlist:
  | tail { }
  | dlist AUTO dlets tail { }
  ;

stat:
  | stat1 { $1 }
  | nase { if !silent then $1 ^ "s." else $1 }
  ;

pstat:
  | stat1 { if !silent then $1 ^ "0" else $1 }
  | nase { if not !silent then $1 ^ "ps." else $1 }
  ;

stat1:
  | /* empty */ { "" }
  | ase { $1 ^ "s." }
  | SCALE ASSIGN e { $3 ^ "k" }
  | SCALE EQOP e { "K" ^ $3 ^ $2 ^ "k" }
  | BASE ASSIGN e { $3 ^ "i" }
  | BASE EQOP e { "I" ^ $3 ^ $2 ^ "i" }
  | OBASE ASSIGN e { $3 ^ "o" }
  | OBASE EQOP e { "O" ^ $3 ^ $2 ^ "o" }
  | QSTR { "[" ^ $1 ^ "]P" }
  | BREAK { number (!lev - bstack.(!bindx - 1)) ^ "Q" }
  | PRINT e { $2 ^ "ps." }
  | RETURN e { $2 ^ !post ^ number !lev ^ "Q" }
  | RETURN { "0" ^ !post ^ number !lev ^ "Q" }
  | LBRACE slist RBRACE { $2 }
  | FFF { "fY" }
  | IF crs blev LPAREN re RPAREN stat { conout $7 $2; $5 ^ $2 ^ " " }
  | WHILE crs LPAREN re RPAREN stat blev { conout ($6 ^ $4 ^ $2) $2; $4 ^ $2 ^ " " }
  | fprefix crs re SEMI e RPAREN stat blev { conout ($7 ^ $5 ^ "s." ^ $3 ^ $2) $2; $1 ^ "s." ^ $3 ^ $2 ^ " " }
  | TILDE LETTER ASSIGN e { $4 ^ "S" ^ $2 }
  ;

fprefix: FOR LPAREN e SEMI { $3 };

blev: /* empty */ { decr bindx };

slist:
  | stat { $1 }
  | slist tail stat { $1 ^ $3 }
  ;

tail:
  | NEWLINE { incr line }
  | SEMI { }
  ;

re:
  | e EQ e { $1 ^ $3 ^ "=" }
  | e LT e { $1 ^ $3 ^ ">" }
  | e GT e { $1 ^ $3 ^ "<" }
  | e NE e { $1 ^ $3 ^ "!=" }
  | e GE e { $1 ^ $3 ^ "!>" }
  | e LE e { $1 ^ $3 ^ "!<" }
  | e { $1 ^ " 0!=" }
  ;

nase:
  | LPAREN e RPAREN { $2 }
  | cons { " " ^ $1 ^ " " }
  | DOT cons { " ." ^ $2 ^ " " }
  | cons DOT cons { " " ^ $1 ^ "." ^ $3 ^ " " }
  | cons DOT { " " ^ $1 ^ "." ^ " " }
  | DOT { "l." }
  | LETTER LBRACKET e RBRACKET { $3 ^ ";" ^ array $1 }
  | LETTER INCR { "l" ^ $1 ^ "d1+s" ^ $1 }
  | INCR LETTER { "l" ^ $2 ^ "1+ds" ^ $2 }
  | DECR LETTER { "l" ^ $2 ^ "1-ds" ^ $2 }
  | LETTER DECR { "l" ^ $1 ^ "d1-s" ^ $1 }
  | LETTER LBRACKET e RBRACKET INCR { $3 ^ ";" ^ array $1 ^ "d1+" ^ $3 ^ ":" ^ array $1 }
  | INCR LETTER LBRACKET e RBRACKET { $4 ^ ";" ^ array $2 ^ "1+d" ^ $4 ^ ":" ^ array $2 }
  | LETTER LBRACKET e RBRACKET DECR { $3 ^ ";" ^ array $1 ^ "d1-" ^ $3 ^ ":" ^ array $1 }
  | DECR LETTER LBRACKET e RBRACKET { $4 ^ ";" ^ array $2 ^ "1-d" ^ $4 ^ ":" ^ array $2 }
  | SCALE INCR { "Kd1+k" }
  | INCR SCALE { "K1+dk" }
  | SCALE DECR { "Kd1-k" }
  | DECR SCALE { "K1-dk" }
  | BASE INCR { "Id1+i" }
  | INCR BASE { "I1+di" }
  | BASE DECR { "Id1-i" }
  | DECR BASE { "I1-di" }
  | OBASE INCR { "Od1+o" }
  | INCR OBASE { "O1+do" }
  | OBASE DECR { "Od1-o" }
  | DECR OBASE { "O1-do" }
  | LETTER LPAREN cargs RPAREN { $3 ^ "l" ^ func $1 ^ "x" }
  | LETTER LPAREN RPAREN { "l" ^ func $1 ^ "x" }
  | LETTER { "l" ^ $1 }
  | LENGTH LPAREN e RPAREN { $3 ^ "Z" }
  | SCALE LPAREN e RPAREN { $3 ^ "X" }
  | QUESTION { "?" }
  | SQRT LPAREN e RPAREN { $3 ^ "v" }
  | TILDE LETTER { "L" ^ $2 }
  | SCALE { "K" }
  | BASE { "I" }
  | OBASE { "O" }
  /* (a minus is all of what follows it at its own precedence: -a*b is 0 a b * -) */
  | MINUS e { " 0" ^ $2 ^ "-" }
  | e PLUS e { $1 ^ $3 ^ "+" }
  | e MINUS e { $1 ^ $3 ^ "-" }
  | e STAR e { $1 ^ $3 ^ "*" }
  | e SLASH e { $1 ^ $3 ^ "/" }
  | e PERCENT e { $1 ^ $3 ^ "%" }
  | e CARET e { $1 ^ $3 ^ "^" }
  ;

ase:
  | LETTER ASSIGN e { $3 ^ "ds" ^ $1 }
  | LETTER LBRACKET e RBRACKET ASSIGN e { $6 ^ "d" ^ $3 ^ ":" ^ array $1 }
  | LETTER EQOP e { "l" ^ $1 ^ $3 ^ $2 ^ "ds" ^ $1 }
  | LETTER LBRACKET e RBRACKET EQOP e { $3 ^ ";" ^ array $1 ^ $6 ^ $5 ^ "d" ^ $3 ^ ":" ^ array $1 }
  ;

e:
  | ase { $1 }
  | nase { $1 }
  ;

cargs:
  | eora { $1 }
  | cargs COMMA eora { $1 ^ $3 }
  ;

eora:
  | e { $1 }
  | LETTER LBRACKET RBRACKET { "l" ^ array $1 }
  ;

cons: constant { $1 };

constant:
  | UNDERSCORE { "_" }
  | DIGIT { String.make 1 $1 }
  | constant DIGIT { $1 ^ String.make 1 $2 }
  ;

/* a register for the body that follows; one macro more is entered */
crs:
  | /* empty */
      { let r = Printf.sprintf "<%d>" !crs in
        incr crs;
        if !crs > 220 then (error "program too big"; raise Quit);
        bstack.(!bindx) <- !lev; incr bindx; incr lev;
        r }
  ;

def:
  | DEFINE LETTER LPAREN { pre := ""; post := ""; lev := 1; bindx := 0; bstack.(0) <- 0; func $2 }
  ;

dargs:
  | /* empty */ { }
  | lora { parameter $1 }
  | dargs COMMA lora { parameter $3 }
  ;

dlets:
  | lora { local $1 }
  | dlets COMMA lora { local $3 }
  ;

lora:
  | LETTER { $1 }
  | LETTER LBRACKET RBRACKET { array $1 }
  ;
