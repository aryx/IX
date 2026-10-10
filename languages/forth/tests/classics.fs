\ the classical programs (run.sh's classics)

\ Euclid's
: GCD ( a b -- n ) BEGIN ?DUP WHILE TUCK MOD REPEAT ;
.( gcd: ) 1071 462 GCD . CR

\ Fibonacci's, by a loop
: FIB ( n -- f ) 0 1 ROT 0 ?DO OVER + SWAP LOOP DROP ;
.( fib: ) : FIBS 15 0 DO I FIB . LOOP ; FIBS CR

\ the sieve of Eratosthenes as BYTE printed it (Jim Gilbreath, "A High-Level
\ Language Benchmark", September 1981): the primes below 16384, 1899 of them
8190 CONSTANT SIZE
CREATE FLAGS SIZE 1+ ALLOT
: PRIMES ( -- n )
  FLAGS SIZE 1+ 0 DO 1 OVER I + C! LOOP DROP
  0 SIZE 1+ 0 DO
    FLAGS I + C@ IF
      I DUP + 3 + DUP I +
      BEGIN DUP SIZE <= WHILE 0 OVER FLAGS + C! OVER + REPEAT
      2DROP 1+
    THEN
  LOOP ;
.( sieve: ) PRIMES . CR

\ the towers of Hanoi: the moves counted
VARIABLE MOVES
: HANOI ( n from to via -- )
  3 PICK 0= IF 2DROP 2DROP EXIT THEN
  3 PICK 1- 3 PICK 2 PICK 4 PICK RECURSE
  1 MOVES +!
  3 PICK 1- 1 PICK 3 PICK 5 PICK RECURSE
  2DROP 2DROP ;
.( hanoi: ) 0 MOVES ! 10 1 3 2 HANOI MOVES ? CR

\ a word that defines words: a point's fields
: FIELD ( offset -- offset+1 ) CREATE DUP , 1+ DOES> @ + ;
0 FIELD >X FIELD >Y CONSTANT /POINT
CREATE P /POINT ALLOT
3 P >X ! 4 P >Y !
.( point: ) P >X @ DUP * P >Y @ DUP * + . /POINT . CR

\ a stack of stars
: STARS ( n -- ) 0 ?DO [CHAR] * EMIT LOOP ;
: PYRAMID ( n -- ) 1+ 1 DO 5 I - SPACES I 2* 1- STARS CR LOOP ;
4 PYRAMID

\ the control structures are ordinary words: one more, written here
: UNLESS ( flag -- ) POSTPONE 0= POSTPONE IF ; IMMEDIATE
: CHECK ( n -- ) 10 > UNLESS ." small" ELSE ." large" THEN CR ;
3 CHECK 30 CHECK
