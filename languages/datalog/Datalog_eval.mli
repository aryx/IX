(* A Datalog program run: every rule applied until no tuple is new, the
 * least fixpoint. It ends on any program (no term is made, so the
 * tuples are finite), and neither the rules' order nor a body's changes
 * what is found.
 *
 * - The strata first: a relation that another negates is computed whole
 *   before it. A negation through a recursion has no such order, and is
 *   refused.
 * - In a stratum, semi-naive: after a first round of every rule, a rule
 *   is run again only with one of its body's atoms taken from the last
 *   round's new tuples (once for each atom of the stratum's relations);
 *   a rule none of whose atoms is new can find nothing new. [naive]
 *   runs every rule on everything each round: the definition, kept to
 *   check the other by.
 * - A body is joined by a plan made once for each rule (and each of
 *   its atoms that the new tuples are taken for): its atoms in an
 *   order chosen, the new tuples' atom first, then each time the atom
 *   with the most columns already known; each atom looked up by those
 *   columns, in an index made the first time they are asked for; each
 *   negation and comparison tested as soon as its variables are bound.
 *   A rule one of whose atoms has no tuple is not run.
 *
 *     edge(a, b). edge(b, c). edge(c, d). edge(d, e).
 *     path(X, Y) :- path(X, Z), edge(Z, Y).
 *     path(X, Y) :- edge(X, Y).
 *
 *     round   path's new tuples   found by                      firings
 *       1     ab bc cd de         every rule on everything         4
 *       2     ac bd ce            round 1's four, each joined      3
 *       3     ad be               round 2's three   with edge      2
 *       4     ae                  round 3's two                    1
 *       5     none: the fixpoint  round 4's one                    0
 *
 * Ten firings for ten tuples (mini-datalog -s: 5 rounds, 10 firings;
 * with the two rules in the other order the first round finds more,
 * a rule seeing at once what the one before it added: 4 rounds).
 * By -naive each round joins all of path with edge again and finds
 * again what it had: 40 firings for the same ten. The reason it is
 * right to look at the new tuples only: a rule's body is a join, and
 * a join gives something new only if one of its inputs has; so, for
 * a body p, q, what is new is (new p) with q, and p with (new q), as
 * a product's derivative is. That is the once for each atom above.
 *
 * Negation needs an order. \+ path(X, Y) is true of what is not in
 * path, which is known only when path is finished: path is in a
 * lower stratum than apart (CLI.mli's example), and is run to its
 * fixpoint first. p(X) :- node(X), \+ q(X) with q(X) :- node(X),
 * \+ p(X) has no such order, and no one least answer either (p(a),
 * or q(a)?): refused.
 *
 * reframe:
 * A compiler's worklist is this. A dataflow analysis (liveness, as
 * mini-cc's Opti and mini-ml's Alloc compute it) puts back on its
 * list the blocks whose input changed and leaves the others: the new
 * tuples are the list. The rounds here and the list there are two
 * shapes of one idea, to compute again only what depends on what
 * changed, which is also a spreadsheet's recalculation and a build
 * tool's (mini-mk).
 *
 * design:
 * The order chosen matters more than all the rest: the order written,
 * the new tuples' atom first, had Plan 9's rc analysed by pointer.dl
 * in 20 million lookups and 6.7 s, where the plan does it in 0.6
 * million and 0.2 s, the same tuples (-profile shows each rule's share).
 *
 * A rule on several domains (-j, OCaml 5's build): its new tuples in
 * chunks, each domain taking the next chunk, testing what its firings
 * find against the relation and against what it found itself, and
 * keeping the rest; the caller adds them, chunk by chunk, so the
 * tuples' order is the same whatever the domains did. Nothing is
 * written while the domains run (the indexes they need are made
 * before), so nothing is locked. mini-ml and the assembler with
 * lib_core (98 s on one core by OCaml 5): 52.7 s on 4 domains, 37.8
 * on 8, 28.8 on 32, 32.1 on 64. What stays on one domain is adding the new
 * tuples (11.6 million, to the set and the indexes: 13 to 15 s), so
 * the indexes as flat as Tuples, or each domain adding its share of
 * the hashes, come before more cores.
 * old: without each domain's own set, a tuple found by a thousand
 * firings was a thousand candidates: 79.5 s on 16 domains, 11 GB.
 *
 * cs-history:
 * The fixpoint by rounds is the definition of what a program means
 * (van Emden and Kowalski, 1976). Semi-naive evaluation is from the
 * deductive databases of the 1980s (Francois Bancilhon), and
 * stratified negation from Krzysztof Apt, Howard Blair
 * and Adrian Walker (1988), who showed that a program with such an
 * order has one answer that does not depend on the order chosen.
 *
 * road-not-taken:
 * Everything is computed, though one query is asked: every path, for
 * path(a, X). The magic sets (Bancilhon, Maier, Sagiv and Ullman,
 * 1986) rewrite the rules so that, run bottom up, they find only what
 * the question needs, as Prolog would going down; tabling does it in
 * a Prolog, remembering each call's answers (XSB). Here the question
 * is every tuple (an analysis of a whole program), so they would
 * gain nothing, and are not there. They would for a question about
 * one place (what may this pointer be, asked by an editor): the
 * demand-driven pointer analyses (Heintze and Tardieu, 2001) are that.
 *
 * An analysis run again after a file changed starts here from nothing.
 * Incremental evaluation keeps the tuples and follows the change:
 * DRed (Gupta, Mumick and Subrahmanian, 1993) takes out what a deleted
 * fact may have given, then derives again what still holds; DDlog
 * (Ryzhyk and Budiu, VMware, 2019), on McSherry's differential
 * dataflow, counts each tuple's derivations by version, so that an
 * addition and a deletion both flow through the rules as differences.
 *
 * modern:
 * The engines made for analyses compile the rules: Souffle writes a
 * C++ program a file of rules, each relation with the fewest indexes
 * that cover its rules' lookups (chosen before the run, where an
 * index is made here at its first lookup), B-trees and tries for the
 * tuples, a round's outer loop on all the cores. Its join order is
 * chosen by the variables bound, as here, or given (.plan, from a
 * profile). Semmle's QL (CodeQL) orders joins by the relations'
 * estimated sizes, a database's optimizer. LogicBlox joins all the
 * atoms of a body at once (Veldhuizen's leapfrog triejoin, 2014: a
 * variable at a time, each relation a sorted trie), in a time bounded
 * by the largest answer the relations' sizes allow, where joining two
 * atoms at a time can make a larger result on the way. bddbddb
 * (Whaley and Lam, 2004) kept the relations as BDDs, where a
 * context-sensitive analysis's copies of a function for each context
 * share their nodes.
 *
 * References: Ceri, Gottlob and Tanca's survey (CLI.mli) for the
 * evaluation; K. R. Apt, H. A. Blair and A. Walker,
 * "Towards a Theory of Declarative Knowledge" (in Foundations of
 * Deductive Databases and Logic Programming, 1988); F. Bancilhon,
 * D. Maier, Y. Sagiv and J. D. Ullman, "Magic Sets and Other Strange
 * Ways to Implement Logic Programs" (Principles of Database Systems,
 * 1986); Herbert Jordan, Bernhard Scholz and Pavle Subotic,
 * "Souffle: On Synthesis of Program Analyzers" (Computer Aided
 * Verification, 2016); Pavle Subotic and others, "Automatic Index
 * Selection for Large-Scale Datalog Computation" (VLDB 2018); Todd L.
 * Veldhuizen, "Leapfrog Triejoin" (ICDT 2014); John Whaley and Monica
 * S. Lam, "Cloning-Based Context-Sensitive Pointer Alias Analysis
 * Using Binary Decision Diagrams" (PLDI 2004); Leonid Ryzhyk and Mihai
 * Budiu, "Differential Datalog" (Datalog 2.0, 2019); Ashish Gupta,
 * Inderpal Singh Mumick and V. S. Subrahmanian, "Maintaining Views
 * Incrementally" (SIGMOD 1993); Nevin Heintze and Olivier Tardieu,
 * "Demand-Driven Pointer Analysis" (PLDI 2001). *)

type stats = {
  mutable rounds : int;
  mutable firings : int;      (* a rule's body satisfied once *)
  mutable derived : int;      (* of them, a tuple that was new *)
  mutable lookups : int;
  (* each rule's share of them, and its time (-profile) *)
  mutable profile : (Datalog.rule * cost) list;
}

and cost = { mutable fired : int; mutable added : int; mutable looked : int; mutable seconds : float }

(* the domains among which a rule's new tuples are shared, when there
 * are enough of them (1: the caller's alone; more only where
 * Parallel.available) *)
val jobs : int ref

(* Datalog.Error: not stratified *)
val run : naive:bool -> Datalog.t -> stats

(* a query's answers: the tuples of its relation that match, as facts,
 * sorted *)
val answers : Datalog.t -> Datalog.query -> string list
