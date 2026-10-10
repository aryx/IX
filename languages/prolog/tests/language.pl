% The language, a check a line: what holds in Prolog (the standard's
% core) must hold here. A check that fails or throws is said; the last
% line counts them. What it prints is in language.out.

check(Name, Goal) :-
    nb_getval(checks, N), N1 is N + 1, nb_setval(checks, N1),
    (   catch(Goal, E, (write('FAIL '), write(Name), write(': '), print(E), nl, bad))
    ->  true
    ;   write('FAIL '), write(Name), nl, bad
    ).
bad :- nb_getval(failed, F), F1 is F + 1, nb_setval(failed, F1).

% the goal throws error(Formal, _)
throws(Goal, Formal) :- catch((Goal, fail), error(F, _), true), F = Formal.
% a term written as writeq does
shows(T, A) :- term_to_atom(T, A0), A0 == A.

a(1). a(2). a(3).
first(X) :- a(X), !.
first(99).
sign_of(X, Y) :- ( X > 0 -> Y = pos ; X < 0 -> Y = neg ; Y = zero ).
loop(0) :- !.
loop(N) :- N1 is N - 1, loop(N1).
len([], 0).
len([_|T], N) :- len(T, M), N is M + 1.

:- dynamic fact/1, rule/1, never/1.
:- op(700, xfx, likes).
mary likes wine.
john likes X :- mary likes X.

greeting --> [hello], name.
name --> [world].
name --> [prolog].
as(0) --> [].
as(N) --> [a], as(M), { N is M + 1 }.
digits([D|T]) --> [D], { D >= 0'0, D =< 0'9 }, ( digits(T) -> [] ; { T = [] } ).

main :-
    nb_setval(checks, 0), nb_setval(failed, 0),
    unification, order, types, terms, arithmetic, errors, control, exceptions,
    program, answers, lists, atoms, syntax, writing, grammars, deep,
    nb_getval(checks, N), nb_getval(failed, F),
    write(N), write(' checks, '), write(F), write(' failed'), nl.

unification :-
    check(unify, (X = f(Y), Y = 1, X == f(1))),
    check(unify_both, (f(A, b) = f(a, B), A == a, B == b)),
    check(not_unify, \+ a = b),
    check(not_unifiable, f(C, b) \= f(a, C)),
    check(not_unifiable_leaves, (g(D) \= h(D), var(D))),
    check(double_negation, (\+ \+ E = 1, var(E))),
    check(occurs, \+ unify_with_occurs_check(F, f(F))),
    check(occurs_ok, (unify_with_occurs_check(G, f(a)), G == f(a))).

order :-
    check(compare_lt, (compare(O, 1, a), O == (<))),
    check(compare_gt, (compare(O2, f(a), g), O2 == (>))),
    check(compare_eq, (compare(O3, f(X), f(X)), O3 == (=))),
    check(atoms, a @< b),
    check(struct_atom, f(a) @> a),
    check(number_atom, 1 @< a),
    check(var_number, _ @< 1),
    check(by_name, f(b) @< g(a)),
    check(by_arity, f(a, b) @> g(a)),
    check(identical, (f(Y, Y) == f(Y, Y), f(Y, _) \== f(Y, Y))).

types :-
    check(var, (var(_), \+ var(a))),
    check(nonvar, (nonvar(a), \+ nonvar(_))),
    check(atom, (atom(a), atom([]), \+ atom(1), \+ atom(f(x)))),
    check(integer, (integer(1), number(1), \+ integer(a))),
    check(atomic, (atomic(a), atomic(1), \+ atomic(f(x)))),
    check(compound, (compound(f(x)), compound([a]), \+ compound(a))),
    check(callable, (callable(foo), callable(f(x)), \+ callable(1))),
    check(is_list, (is_list([a]), is_list([]), \+ is_list([a|_]), \+ is_list(a))),
    check(ground, (ground(f(a)), \+ ground(f(_)))).

terms :-
    check(functor, (functor(f(a, b), N, A), N == f, A == 2)),
    check(functor_make, (functor(T, f, 2), T = f(X, Y), var(X), var(Y))),
    check(functor_atom, (functor(T2, a, 0), T2 == a)),
    check(functor_number, (functor(1, N3, A3), N3 == 1, A3 == 0)),
    check(arg, (arg(2, f(a, b), Z), Z == b)),
    check(arg_all, (findall(I-V, arg(I, f(a, b), V), L), L == [1-a, 2-b])),
    check(arg_out, \+ arg(3, f(a, b), _)),
    check(univ, (f(a, b) =.. L2, L2 == [f, a, b])),
    check(univ_make, (T4 =.. [g, 1], T4 == g(1))),
    check(univ_atom, (a =.. L5, L5 == [a], T6 =.. [x], T6 == x)),
    check(copy_term, (copy_term(f(P, Q, P), f(P1, Q1, P2)), P1 == P2, P1 \== Q1, P1 \== P)),
    check(term_variables, (term_variables(f(R, g(S, R)), Vs), Vs == [R, S])).

arithmetic :-
    check(precedence, (X is 2 + 3 * 4, X == 14)),
    check(int_division, (7 // 2 =:= 3, -7 // 2 =:= -3)),
    check(mod, (-7 mod 2 =:= 1, 7 mod -2 =:= -1, 7 mod 2 =:= 1)),
    check(rem, (-7 rem 2 =:= -1, 7 rem -2 =:= 1)),
    check(div, (-7 div 2 =:= -4, 7 div 2 =:= 3)),
    check(power, (2 ** 10 =:= 1024, 2 ^ 3 =:= 8, 5 ^ 0 =:= 1)),
    check(min_max, (max(1, 2) =:= 2, min(1, 2) =:= 1)),
    check(abs_sign, (abs(-3) =:= 3, sign(-3) =:= -1, sign(0) =:= 0)),
    check(bits, (5 /\ 3 =:= 1, 5 \/ 3 =:= 7, 5 xor 3 =:= 6, 1 << 4 =:= 16, 16 >> 2 =:= 4, \ 0 =:= -1)),
    check(gcd, gcd(12, 18) =:= 6),
    check(negative, (Y is - (3), Y == -3, Z is 3 - -3, Z == 6)),
    check(codes, (0'a =:= 97, 0x1F =:= 31)),
    check(comparison, (1 < 2, 2 > 1, 1 =< 1, 1 >= 1, 1 =\= 2, 1 + 1 =:= 2)),
    check(succ, (succ(3, A), A == 4, succ(B, 4), B == 3)),
    check(plus, (plus(1, 2, C), C == 3, plus(1, D, 3), D == 2)),
    check(is_fails, \+ 3 is 1 + 1).

errors :-
    check(not_evaluable, throws(_ is foo + 1, type_error(evaluable, foo/0))),
    check(unbound_in_is, throws(_ is _ + 1, instantiation_error)),
    check(zero_divisor, throws(_ is 1 // 0, evaluation_error(zero_divisor))),
    check(unbound_atom, throws(atom_length(_, _), instantiation_error)),
    check(unknown, throws(nope(1), existence_error(procedure, nope/1))),
    check(not_callable, throws(call(1), type_error(callable, 1))),
    check(unbound_goal, throws(call(_), instantiation_error)),
    check(arg_type, throws(arg(x, f(a), _), type_error(integer, x))),
    check(static, throws(assertz(atom_length(a, b)), permission_error(modify, static_procedure, atom_length/2))),
    check(unbound_throw, throws(throw(_), instantiation_error)).

control :-
    check(disjunction, (findall(X, (X = 1 ; X = 2), L), L == [1, 2])),
    check(negation, (\+ fail, \+ \+ true)),
    check(if_then_else, ((fail -> fail ; true), (true -> true ; fail))),
    check(if_then, (\+ (fail -> true), (true -> true))),
    check(if_commits, (findall(Y, (a(Y) -> true ; Y = none), L2), L2 == [1])),
    check(if_chain, (sign_of(5, pos), sign_of(-5, neg), sign_of(0, zero))),
    check(cut, (findall(Z, first(Z), L3), L3 == [1])),
    check(cut_in_call, (findall(W, (call((a(W), !)) ; W = other), L4), L4 == [1, other])),
    check(cut_in_findall, (findall(V, (a(V), !), L5), L5 == [1])),
    check(cut_in_negation, (\+ (a(_), !, fail), a(_))),
    check(once, (once(a(A)), A == 1)),
    check(ignore, (ignore(fail), ignore(true))),
    check(forall, (forall(a(B), B > 0), \+ forall(a(C), C > 1))),
    check(not, (not(fail), \+ not(true))),
    check(call_n, (call(plus(1), 2, D), D == 3)),
    check(call_closure, (G = append([a]), call(G, [b], E), E == [a, b])),
    check(backtracking, (findall(P-Q, (a(P), a(Q), P < Q), L6), L6 == [1-2, 1-3, 2-3])).

exceptions :-
    check(catch, catch(throw(my), my, true)),
    check(catch_unifies, (catch(throw(f(1)), f(X), true), X == 1)),
    check(catch_outer, catch(catch(throw(a), b, fail), a, true)),
    check(catch_ended, catch((catch(a(Y), _, fail), Y >= 2, throw(late)), late, true)),
    check(catch_undoes, (catch((Z = 1, throw(e)), e, true), var(Z))),
    check(catch_keeps, (catch(W = 1, _, true), W == 1)),
    check(catch_answers, (findall(V, catch(a(V), _, true), L), L == [1, 2, 3])),
    check(recovery_fails, \+ catch(throw(x), x, fail)),
    check(ball_copied, (catch(throw(g(_)), B, true), B = g(C), var(C))).

program :-
    check(assert, (assertz(fact(1)), assertz(fact(2)), asserta(fact(0)), findall(X, fact(X), L), L == [0, 1, 2])),
    check(retract, (retract(fact(1)), findall(Y, fact(Y), L2), L2 == [0, 2])),
    check(retract_fails, \+ retract(fact(7))),
    check(retract_binds, (retract(fact(Z)), Z == 0)),
    check(retractall, (retractall(fact(_)), \+ fact(_))),
    check(rule, (assertz((rule(A) :- fact(A), A > 1)), assertz(fact(5)), rule(B), B == 5)),
    check(clause, (clause(rule(C), Body), Body = (fact(C2), C2 > 1), C == C2)),
    check(clause_fact, (clause(fact(5), T), T == true)),
    check(declared, \+ never(_)),
    check(current_predicate, (current_predicate(first/1), \+ current_predicate(nope/1))),
    check(operator_in_file, (mary likes D, D == wine, john likes E, E == wine)),
    check(counter, (nb_setval(k, 41), nb_getval(k, K0), K1 is K0 + 1, nb_setval(k, K1), nb_getval(k, K2), K2 == 42)).

answers :-
    check(findall_none, (findall(X, fail, L), L == [])),
    check(findall_copies, (findall(Y, member(Y, [_, _]), L2), L2 = [A, B], A \== B)),
    check(bagof_none, \+ bagof(Z, fail, _)),
    check(bagof, (bagof(W, a(W), L3), L3 == [1, 2, 3])),
    check(bagof_groups, (findall(K-Vs, bagof(V, member(K-V, [a-1, b-2, a-3]), Vs), L4), L4 == [a-[1, 3], b-[2]])),
    check(bagof_caret, (bagof(V2, K2^member(K2-V2, [a-1, b-2, a-3]), L5), L5 == [1, 2, 3])),
    check(setof, (setof(C, member(C, [c, a, b, a]), L6), L6 == [a, b, c])),
    check(count, (aggregate_all(count, a(_), N), N == 3)),
    check(sum, (aggregate_all(sum(D), a(D), S), S == 6)),
    check(max, (aggregate_all(max(E), a(E), M), M == 3)).

lists :-
    check(append, (append([a], [b], X), X == [a, b])),
    check(append_back, (append(Y, [c], [a, b, c]), Y == [a, b])),
    check(append_all, (findall(P-Q, append(P, Q, [1, 2]), L), L == [[]-[1, 2], [1]-[2], [1, 2]-[]])),
    check(append_lists, (append([[a], [b, c], []], Z), Z == [a, b, c])),
    check(member, (member(b, [a, b]), \+ member(c, [a, b]), memberchk(a, [a, a]))),
    check(length, (length([a, b], N), N == 2, length(L2, 2), L2 = [_, _])),
    check(length_grows, (length(L3, N3), N3 >= 2, !, L3 = [_, _])),
    check(reverse, (reverse([1, 2, 3], R), R == [3, 2, 1])),
    check(nth, (nth0(1, [a, b, c], E0), E0 == b, nth1(1, [a, b, c], E1), E1 == a)),
    check(nth_all, (findall(I, nth1(I, [a, b], _), Is), Is == [1, 2])),
    check(last, (last([a, b, c], La), La == c)),
    check(sums, (sum_list([1, 2, 3], S), S == 6, max_list([1, 3, 2], Mx), Mx == 3, min_list([2, 1, 3], Mn), Mn == 1)),
    check(numlist, (numlist(1, 3, Ns), Ns == [1, 2, 3])),
    check(msort, (msort([b, a, c, a], M), M == [a, a, b, c])),
    check(sort, (sort([b, a, c, a], So), So == [a, b, c])),
    check(sort_order, (sort([b, 1, f(x), a, 2], So2), So2 == [1, 2, a, b, f(x)])),
    check(keysort, (keysort([b-1, a-2, b-0, a-1], Ks), Ks == [a-2, a-1, b-1, b-0])),
    check(select, (select(b, [a, b, c], Se), Se == [a, c])),
    check(permutation, (findall(Pe, permutation([1, 2, 3], Pe), Ps), length(Ps, 6), sort(Ps, Ps2), length(Ps2, 6))),
    check(delete, (delete([a, b, a, c], a, De), De == [b, c])),
    check(sets, (subtract([1, 2, 3], [2], Su), Su == [1, 3], intersection([1, 2, 3], [2, 3, 4], In), In == [2, 3],
                 union([1, 2], [2, 3], Un), Un == [1, 2, 3], list_to_set([a, b, a], Ls), Ls == [a, b])),
    check(include, (include(integer, [a, 1, b, 2], Inc), Inc == [1, 2], exclude(integer, [a, 1, b, 2], Exc), Exc == [a, b])),
    check(maplist, (maplist(succ, [1, 2], Ml), Ml == [2, 3], maplist(atom, [a, b]), \+ maplist(atom, [a, 1]))),
    check(foldl, (foldl(plus, [1, 2, 3], 0, Fo), Fo == 6)),
    check(between, (findall(B, between(1, 3, B), Bs), Bs == [1, 2, 3], between(1, 3, 2), \+ between(1, 3, 5))).

atoms :-
    check(atom_codes, (atom_codes(abc, L), L == "abc", atom_codes(A, "xy"), A == xy)),
    check(atom_chars, (atom_chars(abc, L2), L2 == [a, b, c], atom_chars(A2, [x, y]), A2 == xy)),
    check(atom_length, (atom_length(hello, 5), atom_length(123, 3), atom_length('', 0))),
    check(char_code, (char_code(a, 97), char_code(C, 0'b), C == b)),
    check(atom_number, (atom_number('42', N), N == 42, \+ atom_number(foo, _), atom_number(A3, 7), A3 == '7')),
    check(number_codes, (number_codes(N2, "12"), N2 == 12, number_codes(34, L3), L3 == "34")),
    check(atom_concat, (atom_concat(ab, cd, X), X == abcd)),
    check(atom_concat_all, (findall(P-Q, atom_concat(P, Q, ab), L4), L4 == [''-ab, a-b, ab-''])),
    check(atom_concat_back, (atom_concat(Y, cd, abcd), Y == ab)),
    check(sub_atom, (sub_atom(hello, 0, 2, _, S), S == he, sub_atom(hello, B, _, 0, lo), B == 3)),
    check(sub_atom_count, (findall(S2, sub_atom(abc, _, 2, _, S2), L5), L5 == [ab, bc])),
    check(upcase, (upcase_atom(abc, U), U == 'ABC')),
    check(join, (atomic_list_concat([a, b, c], J), J == abc, atomic_list_concat([a, 1], '-', J2), J2 == 'a-1')),
    check(split, (atomic_list_concat(Sp, '-', 'a-b-c'), Sp == [a, b, c])),
    check(term_to_atom, (term_to_atom(T, 'foo(1, bar)'), T == foo(1, bar))),
    check(empty_codes, (atom_codes(E, []), E == '', atom_codes(E, Ec), Ec == [])).

syntax :-
    check(quoted, (X = 'hello world', atom(X), atom_length(X, 11))),
    check(quote_in_atom, (Y = 'don''t', atom_length(Y, 5))),
    check(escapes, (Z = "a\nb", Z == [97, 10, 98])),
    check(empty_string, "" == []),
    check(list_tail, ([1, 2|T] = [1, 2, 3], T == [3])),
    check(negative_number, (A = -1, integer(A), B = 1 - 1, compound(B), C = a - -1, C = -(a, C2), C2 == -1)),
    check(functional, (D = -(1), compound(D), D = -(D1), D1 == 1)),
    check(clause_term, (E = (a :- b, c), E = (H :- Bo), H == a, Bo == (b, c))),
    check(priorities, ((a, b ; c -> d) = (;(','(a, b), ->(c, d))))),
    check(left_assoc, (1 - 2 - 3 = -(-(1, 2), 3))),
    check(right_assoc, (2 ^ 3 ^ 4 = ^(2, ^(3, 4)), (a, b, c) = ','(a, ','(b, c)))),
    check(mixed, (1 + 2 * 3 = +(1, *(2, 3)))),
    check(prefix, (- - a = -(-(a)), \+ a = \+(a))),
    check(operator_atom, (F = +, atom(F), G = [-, *], length(G, 2))),
    check(curly, ({a, b} = '{}'(','(a, b)))),
    check(bar, ((a | b) = ;(a, b))),
    check(comment_in_term, (I = f(a, /* here */ b), I = f(_, b))),
    check(op, (op(700, xfx, ===), term_to_atom(J, 'a === b'), J =.. [===, a, b])),
    check(current_op, (current_op(P, Ty, mod), P == 400, Ty == yfx)).

writing :-
    check(infix, (shows(1 + 2 * 3, '1+2*3'), shows((1 + 2) * 3, '(1+2)*3'))),
    check(assoc, (shows(1 - (2 - 3), '1-(2-3)'), shows(1 - 2 - 3, '1-2-3'))),
    check(word_operator, (shows(a mod b, 'a mod b'), shows(x is 1, 'x is 1'))),
    check(comma, (shows((a, b), 'a,b'), shows(f((a, b)), 'f((a,b))'))),
    check(clause, shows((a :- b, c), 'a:-b,c')),
    check(signs, (shows(-3, '-3'), shows(-(3), '- 3'), shows(2 - -3, '2- -3'), shows(-(-(a)), '- -a'), shows(-a, '-a'))),
    check(prefix, (shows(\+ a, '\\+a'), shows(f(-), 'f(-)'))),
    check(list, (shows([a, 'B'|c], '[a,\'B\'|c]'), shows([], '[]'), shows("ab", '[97,98]'))),
    check(quotes, (shows('hello world', '\'hello world\''), shows([], '[]'), shows('X', '\'X\''), shows(a_B1, a_B1))),
    check(curly, shows({a, b}, '{a,b}')),
    check(newline, (term_to_atom('\n', A), atom_length(A, 4))),
    check(read_back, (term_to_atom(f('A', "s", [x|_], 1 - -1, 'it''s'), B), term_to_atom(T, B), T = f(Q, S, [x|_], M, I),
                      Q == 'A', S == "s", M == 1 - -1, I == 'it''s')).

grammars :-
    check(phrase, phrase(greeting, [hello, world])),
    check(phrase_all, (findall(X, phrase(greeting, [hello, X]), L), L == [world, prolog])),
    check(phrase_rest, (phrase(greeting, [hello, world, again], R), R == [again])),
    check(counting, (phrase(as(N), [a, a, a]), N == 3)),
    check(generating, (phrase(as(2), L2), L2 == [a, a])),
    check(codes, (phrase(digits(Ds), "42", Rest), Ds == "42", Rest == [])),
    check(body, (phrase(([a], [b]), L3), L3 == [a, b])).

% (20,000: a size the arm emulator ends in some seconds)
deep :-
    check(loop, loop(20000)),
    check(long_list, (numlist(1, 20000, L), length(L, N), N == 20000, sum_list(L, S), S =:= 200010000)),
    check(not_tail, (numlist(1, 20000, L2), len(L2, N2), N2 == 20000)),
    check(long_unify, (numlist(1, 20000, L3), numlist(1, 20000, L4), L3 = L4, L3 == L4)),
    check(long_copy, (numlist(1, 20000, L5), copy_term(L5, L6), msort(L6, L7), L7 == L5)).
