(* Scripted inputs: what the person does, frame by frame, for
 * reproducible runs of a game or an application (-script, see
 * Native_loop_2d and playground3d's Native_loop_3d), e.g. the golden
 * frame of a game after 2 seconds of play (Scenes_2d.ml).
 *
 * A script is a comma-separated list of what:frames, where frames is a
 * single frame n or a range a-b (both included), counted from 1 like
 * the frame of -dump-frame, e.g.
 *
 *   "right:1-60,space:30,up:40-45,space:50"
 *
 * holds the right arrow for the first second, presses space at frame 30
 * (down during that frame, up at the next), jumps with up from 40 to
 * 45, and presses space again at 50. The keys are the playground's
 * names ("space", "a", ...), with left/right/up/down for the arrows.
 *
 * And the mouse, which an application needs and a game rarely does:
 *
 *   "at(-100;80):1-40,click:5,at(60;-20):6-40,click:12"
 *
 * puts the pointer at (-100, 80), clicks there at frame 5, moves to
 * (60, -20) and clicks again at 12. These are playground coordinates,
 * with the origin at the center of the screen and y up; they are
 * separated by a semicolon because commas separate the entries.
 * [click] is the left button, [rclick] the right one and [mclick] the
 * middle one. A click at frame n is the button down during n and up at
 * n+1, which is what makes it a click (Playground.mli's [mclick]).
 *
 * And the wheel (ix: not in the playground's scripts):
 *
 *   "wheel(-3):12"
 *
 * turns it three notches towards you at frame 12 (Playground.mli's
 * [mwheel]: positive is up, away from you).
 *
 * And characters, which are not keys (Playground.mli's [typed]):
 *
 *   "type(edit):30"
 *
 * types "edit" at frame 30, all four characters in that one frame's
 * [typed], as a fast typist's keystrokes arrive between two frames.
 * There can be no comma inside the parentheses, since commas separate
 * the entries, but there can be a colon ("type(about:history):3" types
 * a URL).
 *
 * Where it stands: Session plays a script's frame into a program,
 * for every platform; the tests of games and examples are a script
 * and the sum of the last frame, and the browser's and the office
 * suite's sessions are the same, with clicks and typing.
 *
 * others:
 * This is the same idea as the "input movies" of emulators (the
 * frame-by-frame recordings of the TAS, or tool-assisted speedrun,
 * communities, e.g. FCEUX's .fm2 files) and as the demos of Doom (.lmp
 * files hold the player's inputs, replayed by a deterministic engine;
 * Quake's .dem files record what the server sent instead). With a
 * deterministic game, the inputs are the whole run. *)
(* ix: copied from playground/platforms/native_common/Input_script.mli in
 * the author's playground (docs/plans/done/plan_playground.md) *)

type t

(* [parse s]: the script [s], or [Error msg] for a malformed one *)
val parse : string -> (t, string) result

(* [down script frame]: the keys held during [frame], by their
 * playground names, e.g. ["ArrowRight"; "space"] for frame 30 of the
 * example above *)
val down : t -> int -> string list

(* [changes script frame]: the keys going down (true) or up (false) at
 * the start of [frame], compared with the frame before, e.g. at frame
 * 31 of the example above: [("space", false)]; at frame 1: those down
 * at frame 1 *)
val changes : t -> int -> (string * bool) list

(* [mouse script frame]: where the pointer is at [frame], if the
 * script says. The last [at] covering the frame wins, so a later
 * entry can move the pointer over a stretch an earlier one covers. *)
val mouse : t -> int -> (float * float) option

(* [typed script frame]: the characters the script types at [frame],
 * "" at most frames *)
val typed : t -> int -> string

(* [wheel script frame]: the notches the wheel turned at [frame], 0.
 * at most frames *)
val wheel : t -> int -> float

(* [button_changes script frame]: the mouse buttons going down (true)
 * or up (false) at the start of [frame], each paired with whether it
 * is the right one -- the same edges as [changes], for the two
 * buttons the playground has *)
val button_changes : t -> int -> (bool * bool) list

(* [middle_changes script frame]: the same for the middle button
 * ([mclick]): [true] at the frame it goes down, [false] at the frame it
 * goes up, and nothing at the other frames *)
val middle_changes : t -> int -> bool list
