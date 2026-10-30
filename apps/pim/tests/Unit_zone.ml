(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_zone.mli *)

(* the UTC second of a day and hh:mm *)
let at (y, m, d) (h, mi) : float =
  (float_of_int (Civil.days_from_civil { year = y; month = m; day = d })
   *. 86400.)
  +. float_of_int ((h * 3600) + (mi * 60))

let footer (rule : string) : Zone.t =
  (* a TZif file of no transition: its footer alone, a slim file's *)
  let header =
    "TZif2" ^ String.make 15 '\000'
    ^ String.concat ""
        (List.map
           (fun n -> "\000\000\000" ^ String.make 1 (Char.chr n))
           [ 0; 0; 0; 0; 1; 4 ])
  in
  let ttinfo = "\000\000\000\000\000\000" ^ "UTC\000" in
  match Zone.of_tzif (header ^ ttinfo ^ "\n" ^ rule ^ "\n") with
  | Some z -> z
  | None -> Alcotest.fail ("no zone of " ^ rule)

let check = Alcotest.(check int)

let tests =
  [
    Testo.create "POSIX's rules at their changes" (fun () ->
        let rome = footer "CET-1CEST,M3.5.0,M10.5.0/3" in
        check "winter" 3600 (Zone.offset rome (at (2026, 1, 15) (12, 0)));
        (* March's last Sunday, 2026-03-29, 2:00 CET: 1:00 UTC *)
        check "the minute before" 3600
          (Zone.offset rome (at (2026, 3, 29) (0, 59)));
        check "summer" 7200 (Zone.offset rome (at (2026, 3, 29) (1, 0)));
        (* October's last Sunday, 2026-10-25, 3:00 CEST: 1:00 UTC *)
        check "summer's last minute" 7200
          (Zone.offset rome (at (2026, 10, 25) (0, 59)));
        check "winter again" 3600 (Zone.offset rome (at (2026, 10, 25) (1, 0)));
        let ny = footer "EST5EDT,M3.2.0,M11.1.0" in
        (* March's second Sunday, 2026-03-08, 2:00 EST: 7:00 UTC *)
        check "New York, before" (-18000)
          (Zone.offset ny (at (2026, 3, 8) (6, 59)));
        check "New York, after" (-14400) (Zone.offset ny (at (2026, 3, 8) (7, 0)));
        let sydney = footer "AEST-10AEDT,M10.1.0,M4.1.0/3" in
        check "Sydney's summer, January" 39600
          (Zone.offset sydney (at (2026, 1, 15) (0, 0)));
        check "Sydney's winter, July" 36000
          (Zone.offset sydney (at (2026, 7, 15) (0, 0)));
        check "no summer" 19800
          (Zone.offset (footer "IST-5:30") (at (2026, 7, 1) (0, 0)));
        let day, minute = Zone.clock rome (at (2026, 10, 29) (23, 30)) in
        Alcotest.(check string) "the local day, past midnight" "2026-10-30"
          (Civil.to_string day);
        check "its minute" 30 minute);
    Testo.create "Plan 9's file; TZif's transitions" (fun () ->
        (match Zone.of_plan9 "EST -18000 EDT -14400\n  100 200\n" with
        | Some z ->
            check "before" (-18000) (Zone.offset z 50.);
            check "summer" (-14400) (Zone.offset z 150.);
            check "after" (-18000) (Zone.offset z 250.)
        | None -> Alcotest.fail "Plan 9's file");
        (* a transition at 1000, to the second type, then the rule *)
        let be n =
          String.init 4 (fun k -> Char.chr ((n lsr (8 * (3 - k))) land 255))
        in
        let file =
          "TZif2" ^ String.make 15 '\000'
          ^ String.concat "" (List.map be [ 0; 0; 0; 1; 2; 4 ])
          ^ be 1000 ^ "\001"
          ^ be 3600 ^ "\000\000" ^ be 7200 ^ "\001\000" ^ "CET\000"
          ^ "\nCET-1CEST,M3.5.0,M10.5.0/3\n"
        in
        match Zone.of_tzif file with
        | Some z ->
            check "before its first" 3600 (Zone.offset z 10.);
            (* (past the last transition, the rule: 1970-01-01 is winter) *)
            check "the rule after the last" 3600 (Zone.offset z 2000.);
            check "summer by the rule" 7200
              (Zone.offset z (at (2026, 7, 1) (0, 0)))
        | None -> Alcotest.fail "TZif");
  ]
