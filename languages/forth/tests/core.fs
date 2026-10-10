\ the words, one group a line: what each prints is in core.out (run.sh)
.( stack: ) 1 2 SWAP . . 1 2 OVER . . . 1 2 3 ROT . . . 1 2 3 -ROT . . . 1 2 NIP . 1 2 TUCK . . . 5 DUP . . CR
.( stack2: ) 1 2 2DUP . . . . 1 2 3 4 2SWAP . . . . 1 2 3 4 2OVER . . . . . . 0 ?DUP . 7 ?DUP . . 9 8 7 2 PICK . . . . DEPTH . CR
.( arith: ) 7 3 + . 7 3 - . 7 3 * . 7 3 / . 7 3 MOD . -7 3 / . 7 3 /MOD . . 5 NEGATE . -5 ABS . 3 9 MIN . 3 9 MAX . 4 1+ . 4 1- . 4 2* . CR
.( bits: ) 12 10 AND . 12 10 OR . 12 10 XOR . 0 INVERT . 1 4 LSHIFT . 16 2 RSHIFT . CR
.( compare: ) 1 2 < . 2 1 < . 2 2 = . 2 3 <> . 3 2 > . 2 2 <= . 2 2 >= . 0 0= . 5 0= . -1 0< . 1 0> . TRUE . FALSE . CR
.( return: ) : R1 5 >R R@ R> + ; R1 . CR
.( memory: ) VARIABLE V 42 V ! V @ . 8 V +! V ? HERE 3 , 4 , DUP @ . CELL+ @ . CR
.( base: ) 255 HEX . DECIMAL $FF . %101 . #10 . 'A' . CHAR B . HEX -1F DECIMAL . 5 2 BASE ! . DECIMAL CR
.( if: ) : SIGN DUP 0< IF DROP ." negative" ELSE 0= IF ." zero" ELSE ." positive" THEN THEN SPACE ; -3 SIGN 0 SIGN 3 SIGN CR
.( loops: ) : U5 5 0 DO I . LOOP ; U5 : D5 0 5 DO I . -1 +LOOP ; D5 : BY2 10 0 DO I . 2 +LOOP ; BY2 : NONE 0 0 ?DO I . LOOP ." none" ; NONE CR
.( nested: ) : SQ 3 0 DO 3 0 DO J 3 * I + . LOOP LOOP ; SQ CR
.( leave: ) : L 10 0 DO I 4 = IF LEAVE THEN I . LOOP ." out" ; L : U 10 0 DO I 4 = IF UNLOOP EXIT THEN I . LOOP ; U CR
.( begin: ) : CD BEGIN DUP . 1- DUP 0= UNTIL DROP ; 3 CD : W 0 BEGIN DUP 3 < WHILE DUP . 1+ REPEAT DROP ; W CR
.( again: ) : A 0 BEGIN 1+ DUP 5 = IF . EXIT THEN AGAIN ; A CR
.( recurse: ) : FACT DUP 1 > IF DUP 1- RECURSE * THEN ; 10 FACT . 20 FACT . CR
.( constant: ) 7 CONSTANT SEVEN SEVEN SEVEN * . CR
.( does: ) : ARRAY CREATE CELLS ALLOT DOES> + ; 5 ARRAY A 11 0 A ! 22 4 A ! 0 A @ 4 A @ + . : TIMES CREATE , DOES> @ * ; 3 TIMES TRIPLE 14 TRIPLE . CR
.( create: ) CREATE TABLE 10 , 20 , 30 , TABLE 2 CELLS + @ . ' TABLE >BODY TABLE = . CR
.( tick: ) ' DUP 5 SWAP EXECUTE + . : APPLY EXECUTE ; 3 4 ' * APPLY . : TWICE ['] DUP EXECUTE + ; 21 TWICE . CR
.( text: ) : HI ." hello, " S" world" TYPE ; HI S" abc" SWAP DROP . : STAR [CHAR] * EMIT ; STAR STAR CR
.( comments: ) 1 ( not this 2 ) 3 + . \ nor this
.( literal: ) : K [ 6 7 * ] LITERAL ; K . : IMM 99 . ; IMMEDIATE : USE IMM ; CR
.( postpone: ) : MY-IF POSTPONE IF ; IMMEDIATE : P 1 MY-IF ." yes" THEN ; P : ADD POSTPONE + ; IMMEDIATE : Q 2 3 ADD ; Q . CR
.( state: ) STATE @ . : S STATE @ ; S . BASE @ . CR
.( case: ) 2 dup * . : lower 5 ; LOWER lower + . CR
.( redefine: ) : X 1 ; : Y X ; : X 2 ; X . Y . CR
.( spaces: ) 3 SPACES 42 EMIT BL EMIT 42 EMIT CR
.( stack left: ) .S CR
