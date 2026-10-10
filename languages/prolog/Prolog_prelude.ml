(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Prolog_prelude.mli *)

let text = {|
% control
not(G) :- \+ G.
once(G) :- call(G), !.
ignore(G) :- ( call(G) -> true ; true ).
forall(C, A) :- \+ ( C, \+ A ).
_ ^ G :- call(G).
initialization(G) :- '$initialization'(G).
dynamic((A, B)) :- !, dynamic(A), dynamic(B).
dynamic([]) :- !.
dynamic([A|As]) :- !, dynamic(A), dynamic(As).
dynamic(N/A) :- '$dynamic'(N, A).
% (declared: a call with no clause fails, and is no error)
discontiguous(S) :- dynamic(S).
multifile(S) :- dynamic(S).

% the program
clause(H, B) :- '$clauses'(H, Cs), member('$clause'(H, B, _), Cs).
retract(C) :-
    ( C = (H :- B) -> true ; H = C, B = true ),
    '$clauses'(H, Cs), member('$clause'(H, B, R), Cs), '$erase'(R).
retractall(H) :- functor(H, N, A), '$dynamic'(N, A), fail.
retractall(H) :- retract((H :- _)), fail.
retractall(_).
current_predicate(N/A) :- '$predicates'(L), member(N/A, L).
current_op(P, T, N) :- '$ops'(L), member(op(P, T, N), L).
arg(N, T, A) :- var(N), !, functor(T, _, Arity), between(1, Arity, N), '$arg'(N, T, A).
arg(N, T, A) :- '$arg'(N, T, A).

% numbers
between(L, H, X) :- integer(X), !, L =< X, X =< H.
between(L, H, X) :- L =< H, '$between'(L, H, X).
'$between'(L, L, X) :- !, X = L.
'$between'(L, _, L).
'$between'(L, H, X) :- L1 is L + 1, '$between'(L1, H, X).

% lists
append([], L, L).
append([H|T], L, [H|R]) :- append(T, L, R).
append([], []).
append([L|Ls], As) :- append(L, Ws, As), append(Ls, Ws).
member(X, [X|_]).
member(X, [_|T]) :- member(X, T).
memberchk(X, L) :- member(X, L), !.
length(L, N) :- is_list(L), !, '$list_length'(L, N).
length(L, N) :- var(N), !, '$length'(L, 0, N).
length(L, N) :- integer(N), N >= 0, '$make_list'(N, L).
'$length'([], N, N).
'$length'([_|T], N0, N) :- N1 is N0 + 1, '$length'(T, N1, N).
'$make_list'(0, L) :- !, L = [].
'$make_list'(N, [_|T]) :- N1 is N - 1, '$make_list'(N1, T).
reverse(L, R) :- '$reverse'(L, [], R).
'$reverse'([], A, A).
'$reverse'([H|T], A, R) :- '$reverse'(T, [H|A], R).
nth0(I, L, E) :- '$nth'(L, 0, I, E).
nth1(I, L, E) :- '$nth'(L, 1, I, E).
'$nth'(L, B, I, E) :- integer(I), !, Skip is I - B, Skip >= 0, '$skip'(Skip, L, [E|_]).
'$nth'([H|T], B, I, E) :- '$nth_var'(T, H, B, I, E).
'$nth_var'(_, H, B, B, H).
'$nth_var'([H|T], _, B, I, E) :- B1 is B + 1, '$nth_var'(T, H, B1, I, E).
'$skip'(0, L, L) :- !.
'$skip'(N, [_|T], L) :- N1 is N - 1, '$skip'(N1, T, L).
last([X], X).
last([_|T], X) :- last(T, X).
sum_list(L, S) :- '$sum'(L, 0, S).
sumlist(L, S) :- '$sum'(L, 0, S).
'$sum'([], S, S).
'$sum'([H|T], S0, S) :- S1 is S0 + H, '$sum'(T, S1, S).
max_list([H|T], M) :- '$max'(T, H, M).
'$max'([], M, M).
'$max'([H|T], A, M) :- B is max(A, H), '$max'(T, B, M).
min_list([H|T], M) :- '$min'(T, H, M).
'$min'([], M, M).
'$min'([H|T], A, M) :- B is min(A, H), '$min'(T, B, M).
numlist(L, H, []) :- L > H, !.
numlist(L, H, [L|T]) :- L1 is L + 1, numlist(L1, H, T).
select(X, [X|T], T).
select(X, [H|T], [H|R]) :- select(X, T, R).
permutation([], []).
permutation(L, [H|T]) :- select(H, L, R), permutation(R, T).
delete([], _, []).
delete([H|T], X, R) :- ( H \= X -> R = [H|R1] ; R = R1 ), delete(T, X, R1).
subtract([], _, []).
subtract([H|T], L, R) :- ( memberchk(H, L) -> R = R1 ; R = [H|R1] ), subtract(T, L, R1).
intersection([], _, []).
intersection([H|T], L, R) :- ( memberchk(H, L) -> R = [H|R1] ; R = R1 ), intersection(T, L, R1).
union([], L, L).
union([H|T], L, R) :- ( memberchk(H, L) -> R = R1 ; R = [H|R1] ), union(T, L, R1).
list_to_set(L, S) :- '$set'(L, [], S).
'$set'([], _, []).
'$set'([H|T], Seen, R) :- ( memberchk(H, Seen) -> R = R1 ; R = [H|R1] ), '$set'(T, [H|Seen], R1).
include(P, L, R) :- '$include'(L, P, R).
'$include'([], _, []).
'$include'([X|Xs], P, R) :- ( call(P, X) -> R = [X|R1] ; R = R1 ), '$include'(Xs, P, R1).
exclude(P, L, R) :- '$exclude'(L, P, R).
'$exclude'([], _, []).
'$exclude'([X|Xs], P, R) :- ( call(P, X) -> R = R1 ; R = [X|R1] ), '$exclude'(Xs, P, R1).
maplist(G, L) :- '$maplist'(L, G).
'$maplist'([], _).
'$maplist'([X|Xs], G) :- call(G, X), '$maplist'(Xs, G).
maplist(G, L1, L2) :- '$maplist'(L1, L2, G).
'$maplist'([], [], _).
'$maplist'([X|Xs], [Y|Ys], G) :- call(G, X, Y), '$maplist'(Xs, Ys, G).
maplist(G, L1, L2, L3) :- '$maplist'(L1, L2, L3, G).
'$maplist'([], [], [], _).
'$maplist'([X|Xs], [Y|Ys], [Z|Zs], G) :- call(G, X, Y, Z), '$maplist'(Xs, Ys, Zs, G).
foldl(G, L, A0, A) :- '$foldl'(L, G, A0, A).
'$foldl'([], _, A, A).
'$foldl'([X|Xs], G, A0, A) :- call(G, X, A0, A1), '$foldl'(Xs, G, A1, A).

% all the answers
findall(T, G, L, Tail) :- findall(T, G, L0), append(L0, Tail, L).
bagof(T, G0, L) :- '$bagof_split'(T, G0, G, Ws), '$bagof'(Ws, T, G, L).
'$bagof'([], T, G, L) :- !, findall(T, G, L), L \== [].
'$bagof'(Ws, T, G, L) :-
    W =.. ['$free'|Ws], findall(W-T, G, Ps), Ps \== [],
    keysort(Ps, Sorted), '$groups'(Sorted, Groups), member(W-L, Groups).
'$groups'([], []).
'$groups'([K-V|Ps], [K-[V|Vs]|Gs]) :- '$same_key'(Ps, K, Vs, Rest), '$groups'(Rest, Gs).
'$same_key'([K1-V|Ps], K, [V|Vs], Rest) :- K1 == K, !, '$same_key'(Ps, K, Vs, Rest).
'$same_key'(Ps, _, [], Ps).
setof(T, G, L) :- bagof(T, G, L0), sort(L0, L).
aggregate_all(count, G, N) :- !, findall(x, G, L), length(L, N).
aggregate_all(sum(E), G, S) :- !, findall(E, G, L), sum_list(L, S).
aggregate_all(max(E), G, M) :- !, findall(E, G, L), L = [_|_], max_list(L, M).
aggregate_all(min(E), G, M) :- !, findall(E, G, L), L = [_|_], min_list(L, M).
aggregate_all(bag(E), G, L) :- !, findall(E, G, L).
aggregate_all(set(E), G, S) :- findall(E, G, L), sort(L, S).

% atoms
atom_concat(A, B, C) :- nonvar(A), nonvar(B), !, '$atom_concat'(A, B, C).
atom_concat(A, B, C) :- atom_codes(C, Cs), append(As, Bs, Cs), atom_codes(A, As), atom_codes(B, Bs).
sub_atom(A, B, L, Af, Sub) :-
    atom_codes(A, Cs), ( var(Sub) -> true ; atom_codes(Sub, SubCs) ),
    append(Pre, Rest, Cs), append(SubCs, Post, Rest),
    length(Pre, B), length(SubCs, L), length(Post, Af), atom_codes(Sub, SubCs).
concat_atom(L, A) :- atomic_list_concat(L, A).
concat_atom(L, S, A) :- atomic_list_concat(L, S, A).

% grammars: a rule H --> B is a clause with two more arguments, the
% text before and the text after
phrase(G, L) :- phrase(G, L, []).
phrase(G, L, R) :- '$dcg_body'(G, S0, S, B), S0 = L, S = R, call(B).
'$dcg'((H --> B), (H1 :- B1)) :- '$dcg_call'(H, S0, S, H1), '$dcg_body'(B, S0, S, B1).
'$dcg_body'(V, S0, S, phrase(V, S0, S)) :- var(V), !.
'$dcg_body'((A, B), S0, S, (A1, B1)) :- !, '$dcg_body'(A, S0, S1, A1), '$dcg_body'(B, S1, S, B1).
'$dcg_body'((A ; B), S0, S, (A1 ; B1)) :- !, '$dcg_body'(A, S0, S, A1), '$dcg_body'(B, S0, S, B1).
'$dcg_body'((A -> B), S0, S, (A1 -> B1)) :- !, '$dcg_body'(A, S0, S1, A1), '$dcg_body'(B, S1, S, B1).
'$dcg_body'(\+ A, S0, S, (\+ A1, S0 = S)) :- !, '$dcg_body'(A, S0, _, A1).
'$dcg_body'({G}, S0, S, (G, S0 = S)) :- !.
'$dcg_body'(!, S0, S, (!, S0 = S)) :- !.
'$dcg_body'([], S0, S, S0 = S) :- !.
'$dcg_body'(L, S0, S, S0 = Full) :- is_list(L), !, append(L, S, Full).
'$dcg_body'(NT, S0, S, G) :- '$dcg_call'(NT, S0, S, G).
'$dcg_call'(NT, S0, S, G) :- NT =.. L, append(L, [S0, S], L2), G =.. L2.
|}
