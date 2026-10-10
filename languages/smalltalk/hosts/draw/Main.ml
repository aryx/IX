(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-squeak in a window of mini-rio's, under mini-9pi: see Window.mli *)

type caps = < Window.caps; Cap.stdout; Cap.stderr >

let usage = "usage: squeak [-k quiet|squeak|mini]   (-h: how)"

(* -h: how *)
let help = {|usage: squeak [-k quiet|squeak|mini]
Squeak in this window (or on all the screen, with no window system): everything
in it is a morph drawn by Smalltalk. The mouse: left (red) picks up, selects;
right (yellow) a text's menu: do it, print it, accept; middle (blue) a halo.
-k: quiet (the default: nothing moves by itself; the atoms are in the world's
menu, a click on the car script's "paused" starts the car), squeak (the atoms
bouncing, the car driving: slow), mini (MiniMorphic: fifty squares, black and
white). Smalltalk's text is compiled at the start: some seconds. Control-C
stops what runs too long; delete the window to end.|}

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let kernel = ref "quiet" in
  let options = [
    "-k", Arg.Set_string kernel, " quiet|squeak|mini: the start";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how";
  ] in
  match Arg.parse_argv argv options (fun (a : string) -> raise (Arg.Bad (a ^ ": no argument is expected\n"))) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); Exit.OK
  | exception Arg.Bad msg -> Console.eprint caps msg; Exit.Code 1
  | () -> (
      let transcript (s : string) : unit = Console.print caps (String.map (fun (c : char) -> if c = '\r' then '\n' else c) s) in
      match !kernel with
      | "quiet" -> Window.run caps Squeak.Quiet transcript; Exit.OK
      | "squeak" -> Window.run caps Squeak.Squeak transcript; Exit.OK
      | "mini" -> Window.run caps Squeak.Mini transcript; Exit.OK
      | k -> Console.eprint caps ("-k " ^ k ^ ": quiet, squeak or mini\n"); Exit.Code 1)

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
