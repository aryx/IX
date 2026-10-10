% A text with mistakes: each is said with its line, and the rest is read.
ok(1).
bad( :- .
ok(2).
:- X is foo + 1, write(X).
:- fail.
:- nope.
ok(3) :- true.
foo(X) :- X = 'not closed.
