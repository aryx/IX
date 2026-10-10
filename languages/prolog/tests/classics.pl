% The classical programs: what each prints is in classics.out.

% the family: a relation asked both ways
parent(tom, bob).
parent(tom, liz).
parent(bob, ann).
parent(bob, pat).
parent(pat, jim).
grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
ancestor(X, Y) :- parent(X, Y).
ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).

% the eight queens (languages/scheme/tests/queens.scm's count)
queens(N, Qs) :- numlist(1, N, Ns), place(Ns, [], Qs).
place([], Qs, Qs).
place(Unplaced, Safe, Qs) :-
    select(Q, Unplaced, Rest),
    \+ attacks(Q, Safe),
    place(Rest, [Q|Safe], Qs).
attacks(Q, Qs) :- attacks(Q, 1, Qs).
attacks(Q, D, [Y|_]) :- Q =:= Y + D.
attacks(Q, D, [Y|_]) :- Q =:= Y - D.
attacks(Q, D, [_|Ys]) :- D1 is D + 1, attacks(Q, D1, Ys).

% naive reverse: the benchmark the inferences a second are counted by
nrev([], []).
nrev([H|T], R) :- nrev(T, RT), app(RT, [H], R).
app([], L, L).
app([H|T], L, [H|R]) :- app(T, L, R).

% Warren's derivative
d(U + V, X, DU + DV) :- !, d(U, X, DU), d(V, X, DV).
d(U - V, X, DU - DV) :- !, d(U, X, DU), d(V, X, DV).
d(U * V, X, DU * V + U * DV) :- !, d(U, X, DU), d(V, X, DV).
d(U ^ N, X, DU * N * U ^ N1) :- integer(N), !, N1 is N - 1, d(U, X, DU).
d(- U, X, - DU) :- !, d(U, X, DU).
d(X, X, 1) :- !.
d(C, _, 0) :- atomic(C).

% the zebra puzzle: five houses, who owns the zebra, who drinks water
right_of(X, Y, [Y, X|_]).
right_of(X, Y, [_|T]) :- right_of(X, Y, T).
next_to(X, Y, L) :- right_of(X, Y, L).
next_to(X, Y, L) :- right_of(Y, X, L).
zebra(Owner, Drinker) :-
    Hs = [h(_, norwegian, _, _, _), _, h(_, _, _, milk, _), _, _],
    member(h(red, english, _, _, _), Hs),
    member(h(_, spanish, dog, _, _), Hs),
    member(h(green, _, _, coffee, _), Hs),
    member(h(_, ukrainian, _, tea, _), Hs),
    right_of(h(green, _, _, _, _), h(ivory, _, _, _, _), Hs),
    member(h(_, _, snails, _, oldgold), Hs),
    member(h(yellow, _, _, _, kools), Hs),
    next_to(h(_, _, _, _, chesterfield), h(_, _, fox, _, _), Hs),
    next_to(h(_, _, _, _, kools), h(_, _, horse, _, _), Hs),
    member(h(_, _, _, orange_juice, luckystrike), Hs),
    member(h(_, japanese, _, _, parliament), Hs),
    next_to(h(_, norwegian, _, _, _), h(blue, _, _, _, _), Hs),
    member(h(_, Owner, zebra, _, _), Hs),
    member(h(_, Drinker, _, water, _), Hs).

% a grammar: an expression's value
expr(V) --> term(V0), expr_rest(V0, V).
expr_rest(V0, V) --> "+", !, term(V1), { V2 is V0 + V1 }, expr_rest(V2, V).
expr_rest(V0, V) --> "-", !, term(V1), { V2 is V0 - V1 }, expr_rest(V2, V).
expr_rest(V, V) --> [].
term(V) --> factor(V0), term_rest(V0, V).
term_rest(V0, V) --> "*", !, factor(V1), { V2 is V0 * V1 }, term_rest(V2, V).
term_rest(V, V) --> [].
factor(V) --> "(", !, expr(V), ")".
factor(V) --> digits(Ds), { number_codes(V, Ds) }.
digits([D|T]) --> [D], { D >= 0'0, D =< 0'9 }, ( digits(T) -> [] ; { T = [] } ).

% Prolog in three clauses
solve(true) :- !.
solve((A, B)) :- !, solve(A), solve(B).
solve(H) :- clause(H, B), solve(B).

% Hanoi's moves counted, by a counter kept in the program
:- dynamic moves/1.
moves(0).
hanoi(0, _, _, _) :- !.
hanoi(N, A, B, C) :- N1 is N - 1, hanoi(N1, A, C, B), retract(moves(M)), M1 is M + 1, assert(moves(M1)), hanoi(N1, C, B, A).

main :-
    findall(X, grandparent(tom, X), Gs), print(grandchildren(Gs)), nl,
    findall(X, ancestor(X, jim), As), print(ancestors(As)), nl,
    findall(X-Y, append(X, Y, [1,2]), Ss), print(Ss), nl,
    queens(8, Qs), print(Qs), nl,
    findall(Q, queens(6, Q), All), length(All, Count), print(six_queens(Count)), nl,
    numlist(1, 30, L30), nrev(L30, R30), print(R30), nl,
    d(x^2 + 3*x - 5, x, D), print(D), nl,
    zebra(Owner, Drinker), print(zebra(Owner)), nl, print(water(Drinker)), nl,
    phrase(expr(V), "2+3*(4-1)-10"), print(V), nl,
    ( solve(ancestor(tom, jim)) -> print(solved) ; print(unsolved) ), nl,
    hanoi(10, a, b, c), moves(Moves), print(moves(Moves)), nl.
