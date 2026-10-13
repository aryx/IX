/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* pic's grammar, the part that draws: an object a statement (a box, a
 * line, a text, a block of statements between brackets), with what is
 * said of it after its name; places by name and by corner; arithmetic.
 * Its macros are the lexer's (Pic_lexer): they are text put for text.
 * Not here: pic's programming (for, if, sprintf, sh).
 *
 * Two things could be read two ways, and each is said (LOW: lower than
 * what could follow, so what follows is taken):
 *  - a number after a direction is how far (up 0.2), not a move of its
 *    own the way things were going (arrow 0.8); the same after dashed,
 *    dotted, fill and chop;
 *  - in "x, y + ..." the sum is y's. */
%{
open Pic_ast
%}

%token <float> NUMBER
%token <string> STRING LABEL VAR CORNER CORNEROF PRIM DIR JUST
%token <int> ORD
%token WID HT RAD FROM TO AT WITH THEN DASHED DOTTED INVIS FILL SAME CHOP CW CCW LAST HERE
%token HEAD_END HEAD_START HEAD_BOTH
%token COLON LBRACK RBRACK LPAREN RPAREN COMMA PLUS MINUS STAR SLASH LT GT EQ DOT EOL EOF

%nonassoc LOW
%nonassoc NUMBER
%left PLUS MINUS
%left STAR SLASH
%nonassoc UMINUS

%start picture
%type <Pic_ast.statement list> picture

%%

picture: stmts EOF { List.rev $1 }
;
stmts:
    /* nothing */ { [] }
  | stmts EOL { $1 }
  | stmts stmt EOL { $2 :: $1 }
;
stmt:
    LABEL COLON obj { let (k, a) = $3 in Object (Some $1, k, a) }
  | obj { let (k, a) = $1 in Object (None, k, a) }
  | DIR { Direction $1 }
  | VAR EQ expr { Assign ($1, $3) }
;
obj:
    PRIM attrs { ((match $1 with "box" -> Box | "circle" -> Circle | "ellipse" -> Ellipse | "line" -> Line | "arrow" -> Arrow | "arc" -> Arc | "spline" -> Spline | _ -> Move), List.rev $2) }
  | STRING attrs { (Text, Str $1 :: List.rev $2) }
  | LBRACK stmts RBRACK attrs { (Block (List.rev $2), List.rev $4) }
;
attrs:
    /* nothing */ { [] }
  | attrs attr { $2 :: $1 }
;
attr:
    WID expr { Wid $2 }
  | HT expr { Ht $2 }
  | RAD expr { Rad $2 }
  | FROM position { From $2 }
  | TO position { To $2 }
  | AT position { At $2 }
  | WITH CORNER { With $2 }
  | WITH LPAREN expr COMMA expr RPAREN { With "origin" }
  | THEN { Then }
  | DIR %prec LOW { Go ($1, None) }
  | DIR expr { Go ($1, Some $2) }
  | NUMBER { Dist (Num $1) }
  | DASHED %prec LOW { Dashed }
  | DASHED expr { Dashed }
  | DOTTED %prec LOW { Dotted }
  | DOTTED expr { Dotted }
  | INVIS { Invis }
  | FILL %prec LOW { Fill }
  | FILL expr { Fill }
  | SAME { Same }
  | CHOP %prec LOW { Chop }
  | CHOP expr { Chop }
  | HEAD_END { Head (false, true) }
  | HEAD_START { Head (true, false) }
  | HEAD_BOTH { Head (true, true) }
  | CW { Cw }
  | CCW { Ccw }
  | STRING { Str $1 }
  | JUST { Just $1 }
;
position:
    expr COMMA expr %prec LOW { Xy ($1, $3) }
  | LPAREN expr COMMA expr RPAREN { Xy ($2, $4) }
  | place { Place $1 }
  | position PLUS LPAREN expr COMMA expr RPAREN { Shift ($1, $4, $6) }
  | position MINUS LPAREN expr COMMA expr RPAREN { Shift ($1, Neg $4, Neg $6) }
  | expr LT position COMMA position GT { Between ($1, $3, $5) }
;
place:
    path { Named (List.rev $1, None) }
  | cornered { $1 }
  | CORNEROF path { Named (List.rev $2, Some $1) }
  | CORNEROF LAST PRIM { Nth (-1, $3, Some $1) }
  | CORNEROF ORD PRIM { Nth ($2, $3, Some $1) }
;
/* a place that ends with what cannot go on as a name: A.x is then A's x */
cornered:
    path CORNER { Named (List.rev $1, Some $2) }
  | LAST PRIM { Nth (-1, $2, None) }
  | LAST PRIM CORNER { Nth (-1, $2, Some $3) }
  | ORD PRIM { Nth ($1, $2, None) }
  | ORD PRIM CORNER { Nth ($1, $2, Some $3) }
  | HERE { Here }
;
path:
    LABEL { [ $1 ] }
  | path DOT LABEL { $3 :: $1 }
;
expr:
    NUMBER { Num $1 }
  | VAR { Var $1 }
  | expr PLUS expr { Bin ('+', $1, $3) }
  | expr MINUS expr { Bin ('-', $1, $3) }
  | expr STAR expr { Bin ('*', $1, $3) }
  | expr SLASH expr { Bin ('/', $1, $3) }
  | MINUS expr %prec UMINUS { Neg $2 }
  | PLUS expr %prec UMINUS { $2 }
  | cornered DOT VAR { Coord ($1, $3) }
  | path DOT VAR { Coord (Named (List.rev $1, None), $3) }
  | LPAREN expr RPAREN { $2 }
;
