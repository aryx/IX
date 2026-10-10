(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's apps/office/tests/Unit_embed.ml; Component's test only (Compound, a document of parts nested, is not here) (docs/plans/plan_office.md) *)

(* appkit_embed: what a part of a document has to be able to do,
 * tested with a kind of part made up here. *)

let t = Testo.create

(* a part with a size of its own, 100 by 50, that remembers where it
   saw the mouse and in what box -- to see what scaling shows it *)
let rec stamp seen : Component.part =
  {
    kind = "stamp";
    height = (fun _ -> 50.);
    natural = Some (100., 50.);
    draw = (fun b ~active:_ -> [ Playground.rectangle Playground.black b.w b.h |> Playground.move b.x b.y ]);
    input =
      (fun c (b : Widget.box) ->
        stamp (Printf.sprintf "%g,%g in %gx%g" c.mouse.mx c.mouse.my b.w b.h));
    menu = [];
    command = (fun _ -> stamp seen);
    save = (fun () -> seen);
  }

(* the .mli's example: natural 300 x 144 in a room 150 wide is drawn at
   half its size; here 100 x 50 in 50 x 25 *)
let test_scaling () =
  let p = stamp "" in
  Alcotest.(check (float 1e-9)) "scaled: its natural height at the width" 25. (Component.fitted_height ~scaled:true p 50.);
  Alcotest.(check (float 1e-9)) "not: its own" 50. (Component.fitted_height ~scaled:false p 50.);
  Alcotest.(check (float 1e-9)) "and scaled up, as well as down" 100. (Component.fitted_height ~scaled:true p 200.);
  let b : Widget.box = { Widget.x = 25.; y = -12.5; w = 50.; h = 25. } in
  (match Component.draw_in ~scaled:true p b ~active:false with
  | [ s ] ->
      Alcotest.(check (float 1e-9)) "drawn at half its size" 0.5 s.scale;
      Alcotest.(check (pair (float 1e-9) (float 1e-9))) "in the middle of its room" (25., -12.5) (s.x, s.y)
  | l -> Alcotest.failf "%d shapes, not one group" (List.length l));
  (* the room's bottom-right corner is the part's own bottom-right
     corner: the mouse mapped back, and the part never knows *)
  let c = { Playground.initial_computer with mouse = { Playground.initial_computer.mouse with mx = 50.; my = -25. } } in
  Alcotest.(check string) "what the part saw" "50,-25 in 100x50" ((Component.input_in ~scaled:true p c b).save ());
  Alcotest.(check string) "unscaled, the mouse as it is" "50,-25 in 50x25" ((Component.input_in ~scaled:false p c b).save ())

let tests = [ t "scaling: drawn smaller, the mouse mapped back" test_scaling ]
