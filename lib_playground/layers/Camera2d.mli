(* A camera for 2D: worlds bigger than the screen.

   The playground has one screen, centered on (0, 0), and that is enough
   for Pong, Asteroids or Tetris, whose whole world is on screen. But a
   Mario level, a Zelda overworld or a Defender planet is much bigger
   than the screen: the screen shows only a window on the world, and the
   window moves as the player does. That moving window is the camera:

       the world (a Tilemap, or any shapes)
     +----------------------------------------------------------+
     |                                                          |
     |               +-----------------+                        |
     |               |    the screen   |                        |
     |      ##       |        x <---------- (cam.x, cam.y), the  |
     |   ########    |        @        |     world point at the |
     |               +-----------------+     screen's center    |
     |##########################################################|
     +----------------------------------------------------------+

   A camera is nothing new for the playground: it is one [group] of the
   world's shapes, moved by minus the camera's position, and scaled by its
   zoom (see [view]). This module is a layer on top of Playground, like
   Tilemap is a layer on top of this one; it doesn't need anything from a
   backend, so it works everywhere the playground does.

   cs-history:
   A bit of history. The first games didn't scroll: Spacewar! (1962),
   Pong (1972), Space Invaders (1978) fit their world on the screen.
   Scrolling came with the arcade: Speed Race (Taito, 1974) scrolled its
   road vertically, and Defender (Williams, 1981) scrolled a planet
   horizontally, with a minimap (a second, zoomed-out camera!) at the top
   of the screen. Super Mario Bros. (1985) made the side-scroller the
   genre of its decade, thanks to the NES's scroll registers: hardware
   where the camera is two numbers, exactly our [x] and [y]. The PC had
   no such hardware, and John Carmack's "adaptive tile refresh" in
   Commander Keen (id Software, 1990) was the trick that first gave it
   Mario-like smooth scrolling.

   How a camera follows the player is a design question as much as a
   technical one. The classic reference, which names and illustrates the
   techniques of dozens of games, the ones below included, is:
     Itay Keren, "Scroll Back: The Theory and Practice of Cameras in
     Side-Scrollers", GDC 2015 (and its Gamasutra article).
   Each technique is a separate function below, so they can be learned
   (and compared, see TinyMario.ml's camera= flag) one by one.

   Alternatives:
     - a camera inside Playground (a field of [computer], or a [camera]
       function in Playground.mli applied by the backends, as
       playground3d's scenes have one), which would hide it from the
       game, but grow Evan's API;
     - moving every shape by hand (what games without a camera do, e.g.
       subtracting the scroll from each x), which a group does once for
       all;
     - or, in hardware, the scroll registers above.
   Here the camera is a value of the model, which [update] moves like
   the player, so it is visible, testable, and replayable.

   others:
   Related work, the same ideas in other game libraries:
     - PICO-8's camera(x, y): the fantasy console's one-function camera,
       an offset subtracted from every drawing;
     - LÖVE's hump.camera: lookAt, zoom, worldCoords/cameraCoords (our
       [to_world]/[to_screen]), and smoothers (our [follow], [window]);
     - Microsoft MakeCode Arcade's scene.cameraFollowSprite and
       scene.centerCameraAt, for teaching (see Tilemap.mli);
     - Godot's Camera2D: position smoothing, drag margins (a [window]),
       and limits (our [clamp]);
     - in Elm, Zinggi's elm-2d-game has a Game.TwoD.Camera (follow,
       moveTo).
   Evan's elm-playground has no camera: its games fit on the screen.
*)
(* ix: copied from playground/layers/Camera2d.mli in the author's
 * playground (docs/plans/done/plan_playground.md) *)

open Playground

(* The camera:
 * - [x] and [y] are the world point shown at the screen's center;
 * - [zoom] is how much bigger than in the world things look (2. is
 *   twice as big; 0.5 is half as big, and we see twice as much of the
 *   world);
 * - [angle] is how much the camera is turned, in degrees,
 *   counterclockwise; the world then appears turned the other way.
 * With the angle of a car's heading (minus 90), the car always points
 * up the screen and the road turns under it -- the view from its
 * driving seat, flattened; the SNES's Mode 7 turned whole maps this way
 * (F-Zero, 1990). Most 2D games keep the angle at 0, so north stays up,
 * which is easier to read (Micro Machines, 1991, did so; see
 * TinyMicroMachines.ml, whose v key compares the two). *)
type t = { x : number; y : number; zoom : number; angle : number }

(* the camera at (0, 0), with a zoom of 1, not turned: the world
 * coordinates are the screen's, as if there were no camera *)
val origin : t

(* A rectangle in world coordinates, e.g. the part of the world the screen
 * shows (see [visible]), or a level's bounds (see [clamp], and
 * Tilemap.bounds). *)
type rect = { left : number; right : number; bottom : number; top : number }

(*****************************************************************************)
(* {1 Looking through the camera} *)
(*****************************************************************************)

(* [view cam shapes] is the world's [shapes] as the screen shows them
 * through [cam]. Its result goes in the list of [view], next to shapes
 * that don't move with the world: a HUD (a score, lives) is thus just
 * shapes outside the camera:
 *
 *   let view computer model =
 *     [ Camera2d.view model.cam (world model);
 *       words black (score model) |> move 0. (computer.screen.top - 20.) ]
 *
 * A world point p is drawn at zoom * (p - cam) on the screen, turned by
 * -angle. E.g. with the camera at (100, 0) and a zoom of 2, the point
 * (110, 5) is at (20, 10), and the camera's own point (100, 0) is at
 * the center (0, 0). With an angle of 90 too, (110, 5) is at (10, -20):
 * when the camera turns left, the world turns right. (It's [group shapes
 * |> scale zoom |> rotate (-angle) |> move ...]: a group is scaled,
 * then turned, then moved.) *)
val view : t -> shape list -> shape

(* [to_screen cam x y] is where the world point (x, y) is on the
 * screen, zoom * (p - cam) as in [view]. [to_world cam x y] goes the
 * other way round: it is where a screen point is in the world,
 * p / zoom + cam. It is the one games need, because computer.mouse is
 * on the screen:
 *   let wx, wy = Camera2d.to_world cam computer.mouse.mx computer.mouse.my
 * With the camera at (100, 0) and a zoom of 2, to_screen (110, 5) =
 * (20, 10) and to_world (20, 10) = (110, 5). With the camera turned by
 * 90, to_screen (110, 5) = (10, -20), and back. *)
val to_screen : t -> number -> number -> number * number
val to_world : t -> number -> number -> number * number

(* [visible screen cam] is the part of the world the screen shows: the
 * point of [cam], plus or minus half the screen divided by the zoom.
 * E.g. with a 1000x800 screen, the camera at (100, 0) and a zoom of 2,
 * x goes from -150 to 350 and y from -200 to 200. This is what
 * Tilemap.view_visible draws, the rest being off-screen ("culling").
 * When the camera is turned, the screen shows a turned rectangle of the
 * world, and [visible] is the box around it (larger, so culling still
 * misses nothing). *)
val visible : screen -> t -> rect

(*****************************************************************************)
(* {1 Moving the camera: following the player} *)
(*****************************************************************************)
(* Each function below is one of Keren's techniques, from the simplest to
   the most refined; a game calls them in its [update], one after the
   other, e.g. [cam |> window 200. 300. px py |> clamp screen level]. *)

(* [look_at x y cam] centers the camera on (x, y). Called every frame
 * with the player's position, it's what Keren calls "position-locking":
 * the player stays in the middle of the screen, and the world moves
 * under them, even for a tiny step or a hop. It is the simplest camera,
 * and the one of many top-down games. *)
val look_at : number -> number -> t -> t

(* [follow fraction x y cam] moves the camera [fraction] of the way
 * towards (x, y) (0. never, 1. all the way, i.e. [look_at]). Far from
 * its target it moves fast, and close to it slowly, and it stops
 * smoothly instead of with a jolt ("lerp-smoothing", from linear
 * interpolation, or exponential smoothing). E.g. with a fraction of 0.1
 * and the camera at x = 0 following a player standing at x = 100, the
 * camera goes to 10, then 19, then 27.1, ..., getting closer by 10% of
 * the remaining distance each frame. (Because it works per frame, the
 * smoothing depends on the frame rate.) *)
val follow : number -> number -> number -> t -> t

(* [window w h x y cam] doesn't move the camera while (x, y) stays in a
 * w x h window around its center ("camera-window", or dead zone). When
 * (x, y) goes out, the camera is pushed along, just enough to bring
 * (x, y) back to the window's edge. E.g. with w = 200 (the window goes
 * from x - 100 to x + 100) and the camera at x = 0, a player at x = 80
 * doesn't move it, and a player at x = 150 moves it to x = 50.
 *
 *     +---------------------------+  the screen
 *     |       +-----------+       |
 *     |       | the window|  @ -->|  @ out: the camera follows
 *     |       |     x     |       |
 *     |       +-----------+       |
 *     +---------------------------+
 *
 * Small movements, like a jump, don't scroll the screen, which is
 * restful to watch; Super Mario Bros. has a one-sided version (the
 * camera only ever moves right, you can't go back), and Super Mario
 * World (1990) has a refined one. *)
val window : number -> number -> number -> number -> t -> t

(* [turn_toward fraction angle cam] moves the angle of [cam] [fraction]
 * of the way to [angle], the short way round (from 170 to -170, through
 * 180, not through 0). It is [follow] for the angle, for a camera
 * turning smoothly after a car. E.g. from 350, a fraction of 0.5
 * towards 10 gives 0 (360). *)
val turn_toward : number -> number -> t -> t

(* [clamp screen bounds cam] moves the camera (the least possible) so
 * that the screen shows nothing outside [bounds], a level's edges. So at
 * the start of a level, the player is on the left of the screen, not in
 * its middle with emptiness on the left. E.g. with a 1000-wide screen, a
 * zoom of 1, and a level from x = 0 to 3000, the camera's x stays
 * between 500 and 2500. A level smaller than the screen (in a
 * direction) is centered. The angle is ignored: this is for cameras
 * that don't turn. *)
val clamp : screen -> rect -> t -> t

(*****************************************************************************)
(* {1 Rooms: the flip-screen} *)
(*****************************************************************************)

(* A world can be cut in screens, with the camera jumping from one to
 * the next when the player crosses into it, rather than following. This
 * is the "flip-screen" of the 8-bit computers, which could redraw a
 * screen but not scroll one (TinyRick), and of The Legend of Zelda's
 * overworld (TinyZelda, which slides from one to the next). *)

(* [room bounds (w, h) x y] is the w x h room that (x, y) is in, among
 * the rooms tiling [bounds] from its top-left corner. It is a
 * (column, row), with rows going down. E.g. with bounds from x = -1000
 * to 1000 and y = -400 to 400, and rooms of 1000 x 800, (-500, 0) is in
 * room (0, 0), and (500, 0) is in (1, 0). *)
val room : rect -> number * number -> number -> number -> int * int

(* [flip bounds (w, h) x y cam] puts the camera at the center of that
 * room; with the example above, for (500, 0), the camera is at
 * (500, 0) *)
val flip : rect -> number * number -> number -> number -> t -> t

(*****************************************************************************)
(* {1 Parallax: depth with layers} *)
(*****************************************************************************)

(* [parallax factor cam] is a camera for a background layer, which moves
 * [factor] times as much as the world: with 0.5, far mountains scroll at
 * half speed, and the eye sees depth; with 0., the layer is glued to the
 * screen (a sky); with 1., it's the world. E.g. the camera at (100, 40)
 * gives (50, 20) for a factor of 0.5.
 *
 *   [ Camera2d.view (Camera2d.parallax 0.2 cam) mountains;
 *     Camera2d.view (Camera2d.parallax 0.5 cam) hills;
 *     Camera2d.view cam world ]
 *
 * Moon Patrol (Irem, 1982) popularized it in the arcade, with three
 * layers; the idea is older than video games: Disney's multiplane
 * camera (Snow White, 1937) filmed animation drawn on sheets of glass at
 * different distances from the lens. *)
val parallax : number -> t -> t

(* Ideas for more (exercises):
     - screen shake when something explodes (Jan Willem Nijman, "The Art
       of Screen Shake", 2013, Vlambeer's Nuclear Throne);
     - a camera looking ahead in the direction the player runs
       ("forward-focus");
     - a zoom fitting all the players on the screen (Super Smash Bros.,
       1999);
     - a camera snapping vertically only when the player lands on a
       platform ("platform-snapping");
     - a minimap (Defender). *)
