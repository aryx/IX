% what -S shows (run.sh's code): the WAM's instructions for
app([], L, L).                              % the two modes of a list, the last call
app([H|T], L, [H|R]) :- app(T, L, R).
nrev([], []).                               % an environment, a list built
nrev([H|T], R) :- nrev(T, RT), app(RT, [H], R).
color(red). color(green). color(blue).      % the switch on the first argument
shade(X, dark(X)) :- color(X), !.           % a cut after a call
shade(_, none).
max(X, Y, Z) :- ( X >= Y -> Z = X ; Z = Y ). % an if-then-else: a predicate of its own
d(U + V, X, DU + DV) :- d(U, X, DU), d(V, X, DV).  % structures in the head
d(X, X, 1) :- !.
d(C, _, 0) :- atomic(C).
