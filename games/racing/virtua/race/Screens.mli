(* Screens: what is drawn over the picture, the playground's 2D shapes
 * in the screen's coordinates (its middle (0, 0), y up): the race's
 * display and the scenes' texts.
 *
 *   TIME  (the clock)   POSITION 9TH/16            LAP TIME (its time)
 *                                                  BEST (the best lap)
 *                       3, GO!, TIME BONUS +15
 *   the tachometer                                 the map: the road's
 *   (its gear)                                     dots, the rivals,
 *   SPEED 210 km/h  LAPS 2/5                       the player in red
 *
 * The scenes (Virtua's): the title (over the grid, a camera going
 * round the player's car), the course select (the course's miniature
 * turning on a table), the race, and its end (GOAL!, or GAME OVER when
 * the clock ran out). [blink] is the scene's (Scene2d.blink: "PRESS
 * SPACE" shown half of each second). *)

(* [text color size str]: the playground's words, [size] times *)
val text : Playground.color -> float -> string -> Playground.shape

(* frames as minutes, seconds and hundredths, the arcade's way *)
val time_text : int -> string

(* the race's display *)
val race :
  Playground.screen ->
  (Playground.shape list -> Playground.shape list) ->
  Course.t ->
  Race.t ->
  Playground.shape list

(* the title's, the course select's, the end of a race's *)
val title : (Playground.shape list -> Playground.shape list) -> Playground.shape list

val select :
  Playground.screen ->
  (Playground.shape list -> Playground.shape list) ->
  Course.t ->
  Playground.shape list

val finished :
  (Playground.shape list -> Playground.shape list) ->
  Course.t ->
  Race.t ->
  Playground.shape list
