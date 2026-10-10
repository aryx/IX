\ BYTE's benchmark (Jim Gilbreath, September 1981): the sieve, ten times.
\ On an Apple II, 1981: 16 minutes in its Basic; Forth's was a minute or two.
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
: TEN-TIMES 10 0 DO PRIMES DROP LOOP PRIMES . ." primes" CR ;
TEN-TIMES
