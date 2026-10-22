(* Specials: what the lines and the sectors do (Doom's p_spec.c,
 * p_doors.c, p_plats.c, p_floor.c, p_switch.c, p_lights.c).
 *
 * A line's special is a number the map gives it, what it does when it
 * is used (the space key, the nearest line within 64 ahead: DR doors,
 * S switches) or crossed (W, once; WR, again): a door's sector's
 * ceiling goes up to its lowest neighbour's less 4, waits 150 tics,
 * comes down (EV_VerticalDoor, T_VerticalDoor); a lift's floor down to
 * its lowest neighbour's, waits 105, up again (EV_DoPlat,
 * T_PlatRaise); a switch's texture turns (SW1 to SW2,
 * P_ChangeSwitchTexture), and back after a second if it can be used
 * again. A sector's special is its light: flashes, strobes, a glow, a
 * flicker (P_SpawnSpecials).
 *
 *   line 1 (DR), used    a Door thinker on the line's back sector:
 *                        up 2 a tic, 150 tics, down 2 a tic; back up
 *                        if the player is under it (T_MovePlane's
 *                        crush)
 *
 * Each starts a thinker (World), which think moves a tic at a time.
 *
 * What is not here: the specials of the levels after the first
 * (crushers, stairs, teleporters), the damage of a floor (a nukage floor
 * hurts nobody), id's random numbers (these lights flicker by another
 * generator).
 *
 * Where it stands in mini-doom: Play gives it the lines used and
 * crossed, and runs the thinkers each tic. *)

(* [line_special t line used]: the line's special, used or crossed
 * (P_UseSpecialLine, P_CrossSpecialLine); a W1 or S1 one is then no
 * more *)
val line_special : World.t -> Level.line -> bool -> unit

(* a thinker's tic (T_VerticalDoor, T_PlatRaise, T_MoveFloor, the
 * lights', a button's); done, it says so (alive false) *)
val think : World.t -> World.thinker -> unit

(* P_SpawnSpecials: the sectors' lights started *)
val spawn_lights : World.t -> unit
