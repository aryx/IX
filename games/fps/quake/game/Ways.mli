(* Ways: the playground's AI (lib_playground's Ai, over lib_ai's
 * Pathfind) for Quake's monsters, with ai=ways, beside QuakeC's own:
 * a way to the player around the walls, and an aim that gets better.
 *
 * QuakeC's monsters walk as Doom's do (SV_NewChaseDir: the diagonal
 * towards the goal, then the axes, any way, back), and one behind a
 * wall stays there. mini-doom's Ways made the level a grid; a Quake
 * level is 3D, its floors over each other, so here the grid is the
 * player's floor alone, around it: cells of 32 by 32 over 2,048 by
 * 2,048, a cell walkable where the player's hull fits at the player's
 * height and a floor is under it within a step or two:
 *
 *   the player's floor at z     . . # # . . .    # a wall at z, or no
 *   a cell's middle at z:       . . # # . P .      floor under it
 *     hull 1 empty there,       . . . . . . .    each cell's next step
 *     and solid 40 below        . . # # # . .      to P (Ai.flow)
 *
 * Searched again (Ai.flow, Dijkstra's from the player's cell) when the
 * player is in another cell, at most twice a second. A monster on that
 * floor that does not see the player follows its cell's step; one
 * elsewhere, or blocked, QuakeC's way.
 *
 * The aim: Ai.aim_error, a smooth wobble a 16th of a turn wide when
 * the monster first sees the player, halving every 3 seconds it keeps
 * seeing it (30 thinks), added to where QuakeC aims.
 *
 * Where it stands in mini-quake: Monster_ai's ai_run asks [direction] for a
 * monster that does not see the player; the soldiers' and enforcers'
 * attacks turn their aim by [aim_error]. *)

(* [direction w e]: the way towards the player from where the monster
 * is (a yaw, degrees), if the grid knows one *)
val direction : Edict.world -> Edict.t -> float option

(* [aim_error e]: an angle off, in degrees *)
val aim_error : Edict.t -> float
