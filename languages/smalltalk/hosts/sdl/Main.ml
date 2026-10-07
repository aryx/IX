(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-squeak in a window on Linux: see Window.mli *)

type caps = < Cap.stdout; Cap.stderr >

let usage = "usage: mini-squeak [-k squeak|mini] [-x n]   (-h: how)"

(* -h: how, by examples *)
let help = {|usage: mini-squeak [-k squeak|mini] [-x n]
Squeak in a window: Smalltalk-80 "made live again, in colour", where everything
on the screen is a morph drawn by Smalltalk (mini-smalltalk is the machine under
it, and its command on a terminal). For example:
  mini-squeak            the Browser on what draws the atoms, a Workspace, the Transcript, a car and its script
  mini-squeak -x 2       the window twice the Display's 800 by 600
  mini-squeak -k mini    MiniMorphic: Morphic in one file, fifty squares bouncing, black and white
The mouse, by Smalltalk's colours:
  left (red)         picks up what does not want the mouse (a shape, a window by its title) and puts it
                     down; in a text sets the caret and selects; in a list picks; on the world, its menu
  right (yellow)     in a text: do it, print it, inspect it, accept
  middle (blue), or Control and left: a halo on the morph, its handles: delete, pick up, duplicate,
                     resize, inspect, its viewer
To see what it is for: in the Browser, change EllipseMorph>>drawOn:, accept (the
right button's menu), and the atoms bouncing beside it are drawn the new way at
once. Control-C stops what runs too long. Closing the window ends it: nothing
is saved (mini-smalltalk -o saves an image).|}

let main (caps : < caps; .. >) (argv : string array) : int =
  let kernel = ref "squeak" and scale = ref 1 in
  let options = [
    "-k", Arg.Set_string kernel, " squeak|mini: the system";
    "-x", Arg.Set_int scale, " n: the window n times the Display";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how, by examples";
  ] in
  match Arg.parse_argv argv options (fun (a : string) -> raise (Arg.Bad (a ^ ": no argument is expected\n"))) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () -> (
      match !kernel with
      | "squeak" | "mini" ->
          let transcript (s : string) : unit = Console.print caps (String.map (fun (c : char) -> if c = '\r' then '\n' else c) s) in
          (try Window.run (if !kernel = "mini" then Squeak.Mini else Squeak.Squeak) (max 1 !scale) transcript; 0
           with Failure msg | St_boot.Error msg -> Console.eprint caps (msg ^ "\n"); 1)
      | k -> Console.eprint caps ("-k " ^ k ^ ": squeak or mini\n"); 1)

let () = Cap.main (fun caps -> Logging.setup caps ~name:"mini-squeak"; CapStdlib.exit caps (main caps (CapSys.argv caps)))
