(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* counter: two buttons and a number, on the playground's Gui
 * (lib_playground/apis) over lib_gui's widgets. The Gui is immediate
 * mode: no widget is made and kept; at each frame the update asks for
 * each one, where it is and what it shows, and a button answers
 * whether it was just pressed. Layout says where they go, a row in
 * the middle of the window; the view paints what the frame's widgets
 * left to draw. lib_gui/examples/ has the 7GUIs written this way, and
 * the three other ways to write a program with widgets. The mkfile
 * beside it builds it, with lib_gui, lib_playground and the platform:
 *
 *     cd /src/examples; mk; ../_mk/5-plan9/examples/counter
 *     _mk/7/examples/counter -dump-frame 5 frame.ppm     on Linux
 *)
module P = Playground

(* the widgets' names, for their places *)
type slot = Less | Count | More

let panel =
  Layout.center
    (Layout.row ~gap:10.
       [ Layout.leaf Less (Gui.button_size "-");
         Layout.leaf Count (Gui.label_size "0000");
         Layout.leaf More (Gui.button_size "+") ])

let update (computer : P.computer) (n : int) : int =
  let places = Layout.arrange (Gui.area computer) panel in
  let less = Gui.button_in ~enabled:true computer (List.assoc Less places) "-" in
  Gui.label_in computer (List.assoc Count places) (string_of_int n);
  let more = Gui.button_in ~enabled:true computer (List.assoc More places) "+" in
  if less then n - 1 else if more then n + 1 else n

let view (computer : P.computer) (_ : int) : P.shape list =
  let screen = computer.screen in
  let theme : Theme.t = Gui.theme () in
  P.rectangle theme.background screen.width screen.height :: Gui.draw ()

let app = P.game view update 0

let () =
  Cap.main (fun caps ->
      Exit.exit caps
        (Exit.catch (fun () ->
             Playground_platform.run_app caps (Playground_platform.flags caps) app;
             Exit.OK)))
