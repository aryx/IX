(* Ways: the playground's AI (lib_playground's Ai, over lib_ai's
 * Pathfind) for Doom's monsters, with ai=ways: a way through the level
 * to the player, and an aim that gets better.
 *
 * id's monsters go as the crow flies (Enemy's P_NewChaseDir), and one
 * behind a wall stays there. Here the level is seen as a grid of cells
 * of 32 by 32, a cell walkable when no wall crosses its middle and its
 * sector has room to stand (a closed door's has not), and one search
 * from the player's cell outwards (Ai.flow, Dijkstra's) gives every
 * cell the step towards the player: thirty monsters read their own
 * cell's, where thirty searches would be twenty-nine too many.
 *
 *   . . . . # . . . .      the player P; # a wall; each cell's arrow
 *   > > v . # . v < <      its next step (Ai.next_step): around the
 *   > > > > > > P < <      wall's end, through the gap
 *   ^ ^ ^ . # . ^ ^ <
 *
 * The search is made again when the player is in another cell, at most
 * every 16 tics. A step the cells allow that the level does not (a
 * ledge, a thing in the way) fails in P_Move, and id's way takes over
 * for that chase.
 *
 * The aim: Ai.aim_error, a smooth wobble the size of [spread] when the
 * monster first sees the player, halving every 30 tics it keeps seeing
 * it -- a monster that has watched the player a while shoots straight,
 * one surprised does not; the same for the same game, as id's random
 * table is.
 *
 * Where it stands in mini-doom: Enemy's chase asks [direction] of a
 * monster that does not see the player, its attacks [aim_error]. *)

(* [direction t m]: the way towards the player from where the monster
 * is, one of the eight (Enemy's movedir), if the cells know one *)
val direction : World.t -> Things.mobj -> int option

(* [aim_error m]: an angle off, in radians *)
val aim_error : Things.mobj -> float
