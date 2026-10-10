% the control constructs and the database, where the two machines could differ
% (run.sh's control): a clause retracted or added while its predicate is run,
% catch/3 gone back into, cuts inside a disjunction, call/N of a conjunction
:- dynamic q/1, cnt/1.
q(1). q(2). q(3).
t(1) :- findall(X, (q(X), retract(q(X))), L), print(L), nl, findall(Y, q(Y), L2), print(L2), nl.
t(2) :- assert(q(1)), assert(q(2)), findall(X, (q(X), X < 5, Z is X + 10, assertz(q(Z))), L), print(L), nl.
t(3) :- findall(X-Y, catch((member(X, [1,2,3]), (X =:= 2 -> throw(two) ; Y = ok)), two, Y = caught), L), print(L), nl.
t(4) :- catch(member(X, [1,2,3]), _, true), X >= 2, catch(throw(late(X)), late(V), (print(got(V)), nl)).
t(5) :- catch((catch(member(X, [1,2]), inner, true), X =:= 2, throw(inner)), B, (print(outer(B)), nl)).
p(X, R) :- ( X > 10 -> ( X > 100, ! , R = huge ; R = big ) ; X > 5, !, R = mid ; R = small ).
p(_, fallback).
t(6) :- findall(X-R, (member(X, [1, 7, 50, 500]), p(X, R)), L), print(L), nl.
t(7) :- G = (member(X, [a,b,c]), X \== a), findall(X, call(G), L), print(L), nl, ( call((fail ; true)) -> print(yes) ; print(no) ), nl.
t(8) :- \+ \+ (X = 1, print(X), nl), var(X), ( \+ member(z, [a,b]) -> print(notin) ; print(in) ), nl.
t(9) :- catch(call(1), error(E, _), (print(E), nl)), catch(call(_), error(E2, _), (print(E2), nl)), catch(nope(1), error(E3, _), (print(E3), nl)).
t(10) :- length(L, 300), maplist(=(x), L), X = f(L, [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20], g(h(i(j(k))))), X = f(_, [_|T], g(h(i(j(K))))), length(T, N), print(N-K), nl.
t(11) :- forall(member(X, [1,2,3]), X > 0), print(forall), nl, once(member(Z, [a,b])), print(Z), nl, ( member(W, [1,2,3]), W > 1 -> print(W) ; print(none) ), nl.
t(12) :- retractall(cnt(_)), assert(cnt(0)), ( between(1, 1000, _), retract(cnt(C)), C1 is C + 1, assert(cnt(C1)), fail ; true ), cnt(F), print(F), nl.
t(13) :- bagof(X-Y, member(X-Y, [1-a, 2-b, 1-c]), L), print(L), nl, ( setof(K, V^member(K-V, [b-1, a-2, b-3]), S) -> print(S) ; true ), nl.
t(14) :- atom_codes(A, "ab"), catch(atom_length(_, _), error(E, _), true), print(A-E), nl, X = "str", print(X), nl.
t(15) :- a15(X), print(X), nl.
a15(X) :- ( b15(X), X > 1 ; X = none ), !.
b15(1). b15(2). b15(3).
main :- between(1, 15, N), ( catch(t(N), E, (print(err(N, E)), nl)) -> true ; print(failed(N)), nl ), fail.
main.
