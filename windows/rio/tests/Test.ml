(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* What mini-rio's wctl words mean, without a screen: Wctl.parse. The
 * windows themselves are the sessions of kernels/9pi/tests/win-*.steps. *)

let t name f = Testo.create name (fun () -> f (); Testo.Promise.return ())

let screen = Rectangle.v 0 0 1000 800

(* (a rectangle as numbers: Alcotest has no printer for Rectangle.t) *)
let nums (r : Rectangle.t) = (r.min.x, r.min.y, r.max.x, r.max.y)
let rect = Alcotest.(pair (pair int int) (pair int int))
let same what (x0, y0, x1, y1) r =
  let x0', y0', x1', y1' = nums r in
  Alcotest.check rect what ((x0, y0), (x1, y1)) ((x0', y0'), (x1', y1'))

let area text =
  match (Wctl.parse text).area with
  | Some f -> f screen
  | None -> Alcotest.fail ("no area: " ^ text)

let refused text =
  match Wctl.parse text with
  | _ -> Alcotest.fail ("not refused: " ^ text)
  | exception P9_server.Error _ -> ()

let test_at () =
  same "a corner" (680, 0, 1000, 120) (area "new -at ne 320 120 stats");
  same "another" (0, 680, 320, 800) (area "new -at sw 320 120 stats");
  same "the middle" (180, 160, 820, 640) (area "new -at c 640 480 files");
  same "a side" (340, 0, 660, 120) (area "new -at n 320 120 stats");
  same "larger than the screen: all of it" (0, 0, 1000, 800) (area "new -at c 5000 5000 stats");
  same "all of it" (0, 0, 1000, 800) (area "new -max doom");
  refused "new -at elsewhere 320 120 stats";
  refused "new -at ne 320"

let test_new () =
  let c = Wctl.parse "new -label Files -cd /usr/pad -hold -hide files /usr/pad\n" in
  Alcotest.(check string) "the command" "files /usr/pad" c.arg;
  Alcotest.(check string) "its label" "Files" c.label;
  Alcotest.(check string) "its directory" "/usr/pad" c.cd;
  Alcotest.(check bool) "it stays" true c.hold;
  Alcotest.(check bool) "hidden" true c.hidden;
  let plain = Wctl.parse "new" in
  Alcotest.(check string) "rc itself" "" plain.arg;
  Alcotest.(check bool) "no -hold" false plain.hold

let test_rio's () =
  same "-r as before" (1, 2, 300, 400) ((Wctl.parse "new -r 1 2 300 400 x").place screen);
  same "a side moved" (10, 0, 1000, 800) ((Wctl.parse "resize -minx 10").place screen);
  same "by a sign" (0, 0, 1050, 800) ((Wctl.parse "resize -maxx +50").place screen);
  Alcotest.(check bool) "exit is a command" true ((Wctl.parse "exit").verb = Wctl.Exit);
  Alcotest.(check (option int)) "another window" (Some 3) (Wctl.parse "hide -id 3").id;
  refused "exit now";
  refused "resize -nothing";
  refused "nothing"

let () =
  Testo.interpret_argv ~project_name:"mini-rio"
    (fun _ -> [ t "new -at and -max: places whatever the screen" test_at;
                t "new's flags and command" test_new;
                t "rio's own words" test_rio's ])
