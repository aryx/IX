(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Forth_prelude.mli *)

let text : string =
  {|\ a jump's cell is filled when its end is known: HERE is kept on the stack meanwhile
: IF      ['] (0branch) , HERE 0 , ; IMMEDIATE
: THEN    HERE SWAP ! ; IMMEDIATE
: ELSE    ['] (branch) , HERE 0 , SWAP HERE SWAP ! ; IMMEDIATE
: BEGIN   HERE ; IMMEDIATE
: UNTIL   ['] (0branch) , , ; IMMEDIATE
: AGAIN   ['] (branch) , , ; IMMEDIATE
: WHILE   ['] (0branch) , HERE 0 , SWAP ; IMMEDIATE
: REPEAT  ['] (branch) , , HERE SWAP ! ; IMMEDIATE
\ a counted loop: its end (for LEAVE), its limit and its index are on the return stack
: DO      ['] (do) , HERE 0 , HERE ; IMMEDIATE
: ?DO     ['] (?do) , HERE 0 , HERE ; IMMEDIATE
: LOOP    ['] (loop) , , HERE SWAP ! ; IMMEDIATE
: +LOOP   ['] (+loop) , , HERE SWAP ! ; IMMEDIATE
\ the words that define words
: DOES>   ['] (does>) , ; IMMEDIATE
: VARIABLE CREATE 0 , ;
: CONSTANT CREATE , DOES> @ ;
: NIP     SWAP DROP ;
: TUCK    SWAP OVER ;
: -ROT    ROT ROT ;
: 2DUP    OVER OVER ;
: 2DROP   DROP DROP ;
: 2SWAP   ROT >R ROT R> ;
: 2OVER   3 PICK 3 PICK ;
: ?DUP    DUP IF DUP THEN ;
: 1+      1 + ;
: 1-      1 - ;
: 2*      2 * ;
: 0=      0 = ;
: 0<      0 < ;
: 0>      0 > ;
: <>      = 0= ;
: <=      > 0= ;
: >=      < 0= ;
: NEGATE  0 SWAP - ;
: ABS     DUP 0< IF NEGATE THEN ;
: MIN     2DUP > IF SWAP THEN DROP ;
: MAX     2DUP < IF SWAP THEN DROP ;
: /MOD    2DUP MOD -ROT / ;
: +!      DUP @ ROT + SWAP ! ;
: CELLS   ;
: CELL+   1+ ;
: CHARS   ;
: TRUE    -1 ;
: FALSE   0 ;
: BL      32 ;
: SPACE   BL EMIT ;
: SPACES  0 ?DO SPACE LOOP ;
: CR      10 EMIT ;
: TYPE    0 ?DO DUP @ EMIT 1+ LOOP DROP ;
: DECIMAL 10 BASE ! ;
: HEX     16 BASE ! ;
: ?       @ . ;
|}
