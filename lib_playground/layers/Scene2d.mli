(* Scenes: the title screen, the game, the game over screen.

   A game is more than its play: an arcade game shows a title (and waits
   for a coin), then plays, then says GAME OVER and shows the high
   scores, and goes back to the title. Each of these screens is a scene,
   with its own view and its own update; the game's model says which
   scene it is in:

     type scene = Title | Playing of game | Game_over of int (* score *)
(* ix: copied from playground/layers/Scene2d.mli in the author's
   playground, with its optional arguments made required, where it has
   some (docs/plans/done/plan_playground.md) *)

         +-------+  space   +---------+  no lives  +-----------+
     --> | Title | -------> | Playing | ---------> | Game_over |
         +-------+          +---------+            +-----------+
             ^                                           |
             +-------------------------------------------+
                           space, or after 10 seconds

   That's all a scene is, in Elm: a variant in the model, a [match] in
   [view] and [update]. This module adds the two things every such game
   needs and the playground doesn't give:
     - the time spent in the current scene ([elapsed], [frames]), to
       show "PRESS SPACE" blinking, or to go back to the title after 10
       seconds;
     - the keys *pressed*, not held ([pressed]). computer.keyboard says
       which keys are down, so a player still holding space from the
       title would skip the game over screen in one frame. What a scene
       change wants is the moment a key goes down, its "rising edge"
       (the word of electronics, where a signal goes from 0 to 1), and
       seeing it takes remembering the keyboard of the previous frame.
   Both live in a ['scene t] wrapped around the game's own scene type:

     type model = scene Scene2d.t
     let update computer model =
       let model = Scene2d.update computer model in
       match model.scene with
       | Title when Scene2d.pressed (fun k -> k.kspace) model ->
           Scene2d.go (Playing new_game) model
       | ...

   This module is a layer on top of Playground (it only reads the
   computer), like Camera2d.

   cs-history:
   A bit of history. Arcade games invented the scenes to earn coins.
   The "attract mode" is a title and a demo playing by itself while
   nobody plays, to lure passers-by. The high score was kept between
   players by Space Invaders (1978), and Star Fire (1978) and Asteroids
   (1979) added the players' initials to it: three letters for all the
   arcade to see. "GAME OVER" and "INSERT COIN" come from the arcades;
   "PRESS START" comes from the home consoles.

   Alternatives:
     - the game's own variant, with this thin wrapper (ours). It
       follows Richard Feldman's "Making Impossible States Impossible"
       (elm-conf 2016): a [Playing of game] can't exist without a game,
       and a [Game_over] carries only its score;
     - a stack of scenes, where a pause menu is pushed over the game and
       popped back to it, with the game unchanged below. This is the
       pushdown automaton of Robert Nystrom's Game Programming Patterns
       (2014), chapter "State"; our variant does it with
       [Paused of game];
     - scenes as separate apps, each with its view and update, and the
       engine switching between them (Godot's and Unity's scenes, loaded
       from files; PICO-8's _init/_update/_draw, swapped by hand). Each
       scene is independent, but passing data between them (the score to
       the game over) needs a global or a message;
     - transitions (fading to black, wiping). They are nice, but fading
       a whole scene needs a group's alpha, which the renderers don't do
       yet (the TODO in Shape_render_software.ml). They are an exercise,
       as is an attract mode replaying recorded inputs (with the
       time-travel debugger of plan_teaching_other.md).

   terminology:
   A model that is one of a few variants, and events that move it
   from one to another, is a *finite state machine*, and the drawing
   above is its usual picture: a circle for each state, an arrow for
   each event. The type makes it one: [match] has a case for each
   state, and the compiler says when one is forgotten. The same
   machine, with the same name, is found in a lexer (a state per kind
   of token being read), in a network protocol (TCP's states, from
   LISTEN to CLOSED), and in a kernel, for a process (running, ready,
   waiting).

   others:
   Related work: Game Programming Patterns' "State" chapter; LÖVE's
   hump.gamestate (a stack, with enter/leave callbacks); Phaser's scenes;
   MakeCode Arcade's game.over(win) and its splash screens.
*)

open Playground

(* The game's scene, plus what this module keeps track of. [scene] is
 * the only field games set, through [go]; the others are read with the
 * functions below. *)
type 'scene t = {
  scene : 'scene;
  (* seconds since the scene started, and updates since then *)
  elapsed : number;
  frames : int;
  (* the time of the last [update], None before the first *)
  last : number option;
  (* the keyboard at the last update, and at the one before *)
  keys : keyboard;
  before : keyboard;
}

(* [start scene] starts with [scene], the scene the game begins with *)
val start : 'scene -> 'scene t

(* [update computer t] is to be called first thing in the game's
 * [update], every frame. It counts the time, and remembers the
 * keyboard. E.g. after
 * updates at the times 100.0, 100.5 and 101.25, elapsed = 1.25 (the
 * first update only notes the time) and frames = 3. *)
val update : computer -> 'scene t -> 'scene t

(* [go scene t] switches to another scene, whose elapsed time and frames
 * start at 0. The keyboard is remembered, so a key held across the
 * switch isn't [pressed] in the new scene. *)
val go : 'scene -> 'scene t -> 'scene t

(* [pressed key t] tells whether [key] went down at the last update: it
 * is down now, and it was up the frame before. E.g. when space is held
 * for 3 frames, it is pressed at the first, not at the second or
 * third. *)
val pressed : (keyboard -> bool) -> 'scene t -> bool

(* [blink period t shapes] is the [shapes] during the first half of each
 * [period] seconds of the scene, and nothing during the second half.
 * E.g. with a period of 1., they are shown from 0 to 0.5, hidden from
 * 0.5 to 1, and shown again from 1 ("PRESS SPACE", "INSERT COIN"). *)
val blink : number -> 'scene t -> shape list -> shape list
