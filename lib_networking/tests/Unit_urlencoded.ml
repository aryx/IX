(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's playground's libs/networking/tests/Unit_urlencoded.ml (docs/plans/plan_browser.md) *)

(* See Unit_urlencoded.mli *)

let fields = Alcotest.(list (pair string string))

let tests =
  Testo.categorize "Urlencoded"
    [
      Testo.create "the worked example" (fun () ->
          Alcotest.(check string)
            "encoded" "q=caf%C3%A9+au+lait&lang=fr"
            (Urlencoded.encode [ ("q", "caf\xC3\xA9 au lait"); ("lang", "fr") ]);
          Alcotest.check fields "decoded back"
            [ ("q", "caf\xC3\xA9 au lait"); ("lang", "fr") ]
            (Urlencoded.decode "q=caf%C3%A9+au+lait&lang=fr"));
      Testo.create "what separates, escaped" (fun () ->
          Alcotest.(check string) "& = + %" "a=1%262%3D3%2B4%255" (Urlencoded.encode [ ("a", "1&2=3+4%5") ]);
          Alcotest.(check string) "kept" "aZ09*-._" (Urlencoded.escape "aZ09*-._"));
      Testo.create "decoded leniently" (fun () ->
          Alcotest.check fields "no =, a bad %, an empty field"
            [ ("a", ""); ("b", "100%"); ("c", "%zz") ]
            (Urlencoded.decode "a&b=100%&&c=%zz"));
      Testo.create "any bytes, there and back" (fun () ->
          let s = String.init 256 Char.chr in
          Alcotest.(check string) "0-255" s (Urlencoded.unescape (Urlencoded.escape s)));
    ]
