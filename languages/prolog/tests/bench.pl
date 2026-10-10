% naive reverse of 30 elements, n times (bench.sh): 496 inferences each
% (31 of nrev, 465 of app), the count Warren's machine was measured by
app([], L, L).
app([H|T], L, [H|R]) :- app(T, L, R).
nrev([], []).
nrev([H|T], R) :- nrev(T, RT), app(RT, [H], R).
range(N, N, [N]) :- !.
range(I, N, [I|T]) :- I1 is I + 1, range(I1, N, T).
bench(N) :- range(1, 30, L), loop(N, L).
loop(0, _) :- !.
loop(N, L) :- nrev(L, _), N1 is N - 1, loop(N1, L).
% the eight queens, every answer: choice points, arithmetic
queens(N, Qs) :- range(1, N, Ns), perm(Ns, Qs), safe(Qs).
perm([], []).
perm(L, [H|T]) :- sel(H, L, R), perm(R, T).
sel(X, [X|T], T).
sel(X, [H|T], [H|R]) :- sel(X, T, R).
safe([]).
safe([Q|Qs]) :- no_attack(Q, Qs, 1), safe(Qs).
no_attack(_, [], _).
no_attack(Q, [Y|Ys], D) :- Q =\= Y + D, Q =\= Y - D, D1 is D + 1, no_attack(Q, Ys, D1).
all_queens(N, Count) :- findall(Q, queens(N, Q), L), length(L, Count).
