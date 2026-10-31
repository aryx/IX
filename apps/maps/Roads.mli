(* Roads: a small piece of the world's road network, as a graph.

   OpenStreetMap's roads are ways, each a list of nodes, each node a
   latitude and a longitude. Overpass answers a query over them, and what
   mini-maps asks is "the roads a car may use in this box":

     way["highway"~"^(motorway|...|residential)$"](47.3,0.6,47.5,1.0);
     out body; >; out skel qt;

     { "type": "way", "id": 4898610, "nodes": [ 11197711196, 275726429 ],
       "tags": { "highway": "tertiary", "name": "Rue Saint-Barthelemy" } }
     { "type": "node", "id": 275726429, "lat": 47.39, "lon": 0.69 }

   A graph is made of it: a node to each OSM node, an edge to each step of
   a way, two when it may be driven both ways (oneway, a roundabout and a
   motorway say otherwise). An edge's cost is the time, its length at a
   speed given by the road's class:

     residential 30 km/h, tertiary 50, ... motorway 110

   which is a guess: no maxspeed, no traffic, no turn restrictions (OSM
   has them, as relations), no time lost at a junction. So a route here is
   a good way to go, and its minutes are an estimate.

   Costs are whole milliseconds, rounded up: the search then compares
   integers, and both compilers (one fuses a*b+c, Float's rounding differs
   in the last bit) find the same route.

   The Earth is flat here: over half a degree, x is a longitude times the
   cosine of the box's middle latitude, y a latitude, and a distance is
   Pythagoras's (off by about 1% at most over that box). It has one more use:
   a real plane's distances obey the triangle inequality, which A* needs
   (Route).

   Only the largest connected piece is kept. A car park cut off by the
   box's edge or by a road not asked for would otherwise be what the
   nearest node to a click belongs to, and no way would be found.

   The size. A box of 0.12 by 0.41 degrees around Tours and Amboise was
   124,996 nodes and 16,230 ways, 17 MB of JSON, 2.6 MB gzipped, 46 seconds
   of the service (2026-10-31). Overpass's rule for regular use is about
   100 queries and 10 MB a day; and a string on a 32-bit machine stops at
   16 MB. So a box past [all_roads_side] does without the residential
   streets, half of that answer (a long trip hardly uses them; its ends are
   then on the nearest larger road, which is what a road atlas gives). And
   [max_side] limits a box, one extract is kept (Routing), and a route
   across France is not something this does.

   design:
   OSRM's demo server would answer in a few lines of code, but then the
   route is computed elsewhere, and there is nothing left to read here.
   Asking Overpass still needs the network; the search does not.

   cs-history:
   OSM is Steve Coast's, from 2004, when Britain's maps were the Ordnance
   Survey's to sell. Overpass is Roland Olbricht's, a database made for
   reading OSM by what the objects say, not only by where they are.

   Reference: https://wiki.openstreetmap.org/wiki/Overpass_API and
   https://wiki.openstreetmap.org/wiki/Key:highway; the data is OSM's,
   under the ODbL, and credited. *)

type t = {
  lat : float array; (* by node *)
  lon : float array;
  x : float array; (* metres, on the flat Earth above *)
  y : float array;
  shrink : float; (* the cosine that makes a longitude's x *)
  first : int array; (* a node's edges: first.(n) to first.(n+1) - 1 *)
  origin : int array; (* by edge *)
  target : int array;
  millis : int array;
  metres : int array;
  name : int array; (* an index in names *)
  names : string array; (* "" for a road with none *)
  linked : bool array; (* by node: in the largest piece *)
  top_speed : float; (* metres a second, the fastest edge's *)
}

(* the largest side of a box, in degrees *)
val max_side : float

(* the largest side of a box that has the residential streets *)
val all_roads_side : float

(* does the query for that box ask for them? *)
val all_roads : float * float * float * float -> bool

(* the query's address, for a box (south, west, north, east) *)
val url : string -> float * float * float * float -> string

(* the graph of the service's answer; Failure if it is not such an answer *)
val of_json : string -> t

(* the node of the largest piece nearest to a place, and how many metres
 * away; None if the graph has no node *)
val nearest : t -> float -> float -> (int * float) option
