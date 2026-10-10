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
 * - A body is joined in the order written (the new tuples' atom
 *   first), each atom looked up by the columns already known, in an
 *   index made the first time those columns are asked for.
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
 * gain nothing, and are not there.
 *
 * modern:
 * The engines made for analyses compile the rules: Souffle writes a
 * C++ program a file of rules, each relation with the indexes its
 * joins were seen to need, where a hash table is made here at the
 * first lookup; and they choose a join's order, here the order
 * written.
 *
 * References: Ceri, Gottlob and Tanca's survey (CLI.mli) for the
 * evaluation; K. R. Apt, H. A. Blair and A. Walker,
 * "Towards a Theory of Declarative Knowledge" (in Foundations of
 * Deductive Databases and Logic Programming, 1988); F. Bancilhon,
 * D. Maier, Y. Sagiv and J. D. Ullman, "Magic Sets and Other Strange
 * Ways to Implement Logic Programs" (Principles of Database Systems,
 * 1986); Herbert Jordan, Bernhard Scholz and Pavle Subotic,
 * "Souffle: On Synthesis of Program Analyzers" (Computer Aided
 * Verification, 2016). *)

type stats = {
  mutable rounds : int;
  mutable firings : int;      (* a rule's body satisfied once *)
  mutable derived : int;      (* of them, a tuple that was new *)
  mutable lookups : int;
}

(* Datalog.Error: not stratified *)
val run : naive:bool -> Datalog.t -> stats

(* a query's answers: the tuples of its relation that match, as facts,
 * sorted *)
val answers : Datalog.t -> Datalog.query -> string list
