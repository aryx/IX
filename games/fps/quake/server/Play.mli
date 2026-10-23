(* Play: the player's walk (Quake's sv_user.c: SV_ClientThink,
 * SV_UserFriction, SV_Accelerate, SV_AirAccelerate, SV_WaterMove;
 * sv_phys.c: SV_WalkMove, SV_FlyMove, SV_PushEntity; cl_input.c's
 * speeds; view.c's bob), and the level's moving things (Brushes).
 *
 * Each frame, the keys make a wish: a direction and a speed (200 units
 * a second forward, 400 running, 350 aside). On the ground, friction
 * slows the player (4 times the speed a second, at least 100: a stop in
 * a quarter of a second), then the wish accelerates it (10 times the
 * wish a second, up to the wish's speed); in the air, the wish only
 * steers, 30 at most: Quake's air control, which players learned to
 * use (strafe-jumping: a wish at an angle to the speed adds to it).
 * Gravity, 800 units a second squared; a jump, 270 up.
 *
 * The move (SV_FlyMove): the box traced along the velocity (Trace);
 * stopped by a plane, the velocity is made parallel to it (clipped) and
 * the rest of the time traced again, up to four times: the player
 * slides along walls and into corners. A wall that stops it at the
 * feet may be a step (SV_WalkMove): the move is tried again 18 units
 * up, then put down; kept if it ends on a floor (a normal's z above
 * 0.7: 45 degrees), else the move without the step.
 *
 * Where it stands in mini-quake: the game calls frame each frame of
 * the playground, with the time since the last; Render draws from eye,
 * pitch, yaw. *)

type command = {
  forward : bool;
  back : bool;
  left : bool;
  right : bool;
  strafe_left : bool;
  strafe_right : bool;
  jump : bool;
  run : bool;
  look_up : bool;
  look_down : bool;
  use_key : bool;
}

type t = {
  level : Model.t;
  brushes : Brushes.t;
  (* the player: where, how fast, which way, on what *)
  body : Brushes.body;
  mutable pitch : float;
  (* 0 dry, 1 feet, 2 waist, 3 eyes under (SV_CheckWater) *)
  mutable waterlevel : int;
  mutable jump_released : bool;
  mutable use_released : bool;
  (* the time since the start, seconds *)
  mutable time : float;
  (* the light styles' strings, 64 of them (world.qc's, and the
   * switched lights') *)
  styles : string array;
  (* the horizontal speed, for the bob *)
  mutable bob_speed : float;
  (* the boxes in the player's way besides the level's: the monsters'
   * (their absolute mins and maxs), given by the game *)
  mutable boxes : unit -> (Model.vec * Model.vec) list;
}

(* [create m]: the player at info_player_start *)
val create : Model.t -> t

(* [place p origin yaw pitch]: the player there, still *)
val place : t -> Model.vec -> float -> float -> unit

(* [frame p dt c]: dt seconds of the game *)
val frame : t -> float -> command -> unit

(* the eye: 22 units above the origin, bobbing as it walks (V_CalcBob) *)
val eye : t -> Model.vec

(* the yaw *)
val yaw : t -> float

(* the brush models to draw: (entity, model, origin, frame) *)
val bmodels : t -> (int * int * Model.vec * int) list
