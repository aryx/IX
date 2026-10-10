(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/browser/Unit_cors.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Unit_cors.mli *)

let tests =
  Testo.categorize "Cors"
    [
      Testo.create "an origin: the scheme, the host, the port" (fun () ->
          Alcotest.(check (list string)) "of addresses"
            [ "https://example.com"; "https://example.com"; "http://localhost:8000"; "http://site.test"; "https://example.com"; "http://example.com:8080"; "https://example.com"; "null"; "null"; "null" ]
            (List.map Cors.origin
               [ "https://example.com/a/b?q#h"; "https://example.com:443/x"; "http://localhost:8000/"; "http://site.test"; "HTTPS://Example.COM/"; "http://example.com:8080?q";
                 "https://user@example.com/"; "about:tube"; "data:text/plain,hi"; "file:///etc/passwd" ]));
      Testo.create "the worked example: the same origin is all three" (fun () ->
          let page = "https://example.com/shop/cart" in
          Alcotest.(check (list bool)) "the same, the same (its scheme's port), another scheme, host, port" [ true; true; false; false; false ]
            (List.map (Cors.same_origin page) [ "https://example.com/api/items"; "https://example.com:443/x"; "http://example.com/"; "https://api.example.com/"; "https://example.com:8443/" ]));
      Testo.create "who may read: its own origin's answers, and those that say so" (fun () ->
          let page = "https://example.com/shop/cart" in
          let allow v = [ ("Content-Type", "text/plain"); ("access-control-allow-origin", v) ] in
          let readable url headers = Cors.readable ~page ~url headers in
          Alcotest.(check (list bool)) "own; another's, silent; open to all; to this page; to another; to this page's host by another scheme"
            [ true; false; true; true; false; false ]
            [ readable "https://example.com/data" []; readable "https://api.other.test/data" []; readable "https://api.other.test/data" (allow "*");
              readable "https://api.other.test/data" (allow " https://example.com "); readable "https://api.other.test/data" (allow "https://third.test");
              readable "https://api.other.test/data" (allow "http://example.com") ];
          Alcotest.(check string) "what the console says" "https://api.other.test/data has been blocked by CORS policy: no Access-Control-Allow-Origin header for https://example.com"
            (Cors.blocked ~page ~url:"https://api.other.test/data");
          Alcotest.(check (list (option string))) "a header, whatever its case" [ Some "a"; None ] [ Cors.header [ ("X-Thing", "a") ] "x-thing"; Cors.header [] "x-thing" ]);
    ]
