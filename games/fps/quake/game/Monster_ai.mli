(* Monster_ai: how Quake's monsters think (QuakeC's ai.qc, and fight.qc's part
 * every monster shares).
 *
 * A monster's life is its frames (Edict's [seq]: Monsters writes each
 * kind's), one a tenth of a second, each with what to do. [think]
 * shows the frame, makes the next one the next think, and does it:
 *
 *   ai_stand   standing: FindTarget each frame
 *   ai_run     awake: the enemy still there? seen? its range; an
 *              attack if the kind's check says so (Monsters), else a
 *              step towards it (Physics.move_to_goal)
 *   ai_face, ai_charge, ai_back, ai_pain, ai_painforward: turning,
 *              stepping, as the frame asks (an attack's aim, a pain's
 *              stagger)
 *
 * FindTarget is what wakes a monster: the player within 1,000 units,
 * visible (a line from eye to eye that no wall cuts: monsters do not
 * block it), and in front (the sixth of a turn either side) -- or
 * within 500 and just having shot (show_hostile), or another monster
 * that saw the player a tenth of a second ago (sight_entity: a room
 * wakes together). Then FoundTarget: its sight sound, and HuntTarget:
 * the run frames, the first attack a second away.
 *
 *   range: melee < 120, near < 500, mid < 1000, far
 *
 * Where it stands in mini-quake: Monsters' kinds are run by it; Combat
 * makes a hurt monster turn on its attacker by [found_target]. *)

type range = Melee_range | Near | Mid | Far

(* [range w e who] *)
val range : Edict.world -> Edict.t -> Edict.who -> range

(* visible: a line from e's eye to who's, the level only *)
val visible : Edict.world -> Edict.t -> Edict.who -> bool

(* infront: within 72 degrees of where e faces (a dot over 0.3) *)
val infront : Edict.world -> Edict.t -> Edict.who -> bool

(* [start w e seq]: the sequence's first frame, now (QuakeC's call of
 * army_atk1 ()) *)
val start : Edict.world -> Edict.t -> string -> unit

(* [think w e]: a monster's frame *)
val think : Edict.world -> Edict.t -> unit

(* FoundTarget *)
val found_target : Edict.world -> Edict.t -> unit

(* ai_face: turned towards its enemy *)
val face : Edict.world -> Edict.t -> unit
