(* Route: the quickest way between two nodes, by A*.

   Dijkstra's idea: settle the nodes in the order of their distance from
   the start. The nearest node not settled has no shorter way to it, since
   any other way passes through a node at least as far (costs being
   positive). So it spreads like a ring on water, all directions alike:

       Dijkstra: everything nearer           A*: leaning to the goal
       than the goal, on all sides
              . . . . .                               . . .
            . . . . . . .                           . . . . .
          . . . S . . . . G                       S . . . . . G
            . . . . . . .                           . . . . .
              . . . . .                               . . .

   A*'s idea: the same, the order being the distance so far plus an
   estimate of what is left, h(n):

       f(n) = g(n) + h(n)

   Here h is the straight line, at the fastest speed there is in the
   graph. No road is shorter than the straight line and none is faster, so
   h never overestimates ("admissible"), and A* still finds the best way.
   It obeys more, h(a) <= cost(a,b) + h(b), the triangle inequality
   ("consistent"), so that a node once settled stays settled, as in
   Dijkstra's. With h = 0, it is Dijkstra's: one function here, and the
   count of nodes each settles is the lesson, printed by mini-maps route.

   How much better depends on h. In a town at 30 km/h, with a motorway in
   the box, h believes everything can go at 110, and the ring is hardly
   leaning.

   The queue is a binary heap of (f, node). A node whose cost improves is
   pushed again, and the older entry skipped when it comes out, rather than
   looked for ("lazy deletion"): a larger heap, and no index to maintain.

   cs-history:
   Edsger Dijkstra found his algorithm in 1956, on a cafe's terrace in
   Amsterdam, in twenty minutes and with no pencil, to show what the ARMAC,
   a new computer, could do: the way between 64 Dutch towns, for an audience
   who could check it. Published in 1959, three pages. A* comes from
   Stanford Research Institute (Hart, Nilsson and Raphael, 1968), for
   Shakey, a robot that planned where it went. The heap is J. W. J.
   Williams's (1964), for sorting.

   modern:
   Nobody runs this on a continent. A preprocessing step, as Contraction
   Hierarchies (Geisberger and others, 2008) which OSRM uses, adds shortcuts
   over the unimportant roads, and a query across Europe then settles a few
   hundred nodes, in under a millisecond. This is also why a server answers
   so fast. *)

type t = {
  edges : int list; (* in the order driven *)
  millis : int;
  metres : int;
  settled : int; (* the nodes the search took out of its queue *)
}

(* [search g ~guess from goal]: the quickest way, None if there is none;
 * [guess] false is h = 0, Dijkstra's *)
val search : Roads.t -> guess:bool -> int -> int -> t option
