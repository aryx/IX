(* Things: the level's monsters and items, as models standing where the
 * map puts them (QuakeC's monster_army, monster_dog, ... items.qc's
 * weapon_* and item_*: the model each one sets, its skin).
 *
 * Nothing moves here but the models' own animations (a monster's
 * stand frames, ten a second: QuakeC's think every 0.1 s) and the
 * items' turn (EF_ROTATE: 100 degrees a second, CL_RelinkEntities).
 * The monsters do not see, walk nor attack; the items are not picked
 * up (but the keys: Brushes); they are drawn, lit by the floor under
 * them (Alias.light_point).
 *
 * Each falls to the floor under it when the level starts (QuakeC's
 * droptofloor), as the map's origins are a few units above it.
 *
 * The items QuakeC made brush models (the health and ammunition boxes,
 * the explosive barrels: maps/b_*.bsp) are not drawn: LibreQuake
 * ships their sources, not their .bsp. *)

type thing = {
  classname : string;
  origin : Model.vec;
  yaw : float;
  model : Alias.t;
  (* its animation's frames *)
  frames : int array;
  skin : int;
  mutable alive : bool;
}

(* [load m read]: the things of the level's entities whose model
 * (progs/x.mdl) read finds; skill: medium, single player *)
val load : Model.t -> (string -> string option) -> thing list

(* [draw v m things time]: those in the leaves the PVS marked *)
val draw : View.t -> Model.t -> thing list -> float -> unit
