(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/networking/tests/Unit_http.ml (docs/plans/plan_browser.md) *)

(* See Unit_http.mli *)

let ok = function Ok x -> x | Error e -> Alcotest.fail e

(* the response's body, parsed from the status line, the headers and
 * what follows the empty line *)
let body_of (head : string list) (rest : string) : string =
  (ok (Http.parse_response (String.concat "\r\n" head ^ "\r\n\r\n" ^ rest))).body

(* "hi" in one stored block, as a gzip file *)
let hi_gz = "\x1F\x8B\x08\x00\x00\x00\x00\x00\x00\xFF\x01\x02\x00\xFD\xFF\x68\x69\xAC\x2A\x93\xD8\x02\x00\x00\x00"

let wikipedia = "4\r\nWiki\r\n5\r\npedia\r\nE\r\n in\r\n\r\nchunks.\r\n0\r\n\r\n"

let tests =
  Testo.categorize "Http"
    [
      Testo.create "the request of the diagram" (fun () ->
          Alcotest.(check string) "bytes"
            "GET /images/turtle.gif HTTP/1.1\r\nHost: elm-lang.org\r\nUser-Agent: elm_playground\r\nAccept-Encoding: gzip\r\nConnection: close\r\n\r\n"
            (Http.request_to_string ~body:"" (Http.get ~host:"elm-lang.org" "/images/turtle.gif")));
      Testo.create "more said, and the connection asked to stay" (fun () ->
          let r = Http.keeping (Http.saying [ ("Cookie", "a=1") ] (Http.post ~host:"a" ~content_type:"text/plain" ~body:"hi" "/")) in
          Alcotest.(check (list string)) "the headers, Connection the last"
            [ "Host"; "User-Agent"; "Accept-Encoding"; "Content-Type"; "Content-Length"; "Cookie"; "Connection" ]
            (List.map fst r.headers);
          Alcotest.(check (option string)) "asked to stay" (Some "keep-alive") (Http.header "Connection" r.headers);
          Alcotest.(check (list string)) "every header of a name" [ "a=1"; "b=2" ] (Http.values "set-cookie" [ ("Set-Cookie", "a=1"); ("X", "y"); ("set-cookie", "b=2") ]));
      Testo.create "where a response ends: what a kept connection needs" (fun () ->
          let head = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n" in
          Alcotest.(check bool) "the head not whole: not known" true (Http.extent "HTTP/1.1 200 OK\r\nContent-Le" = None);
          (match Http.extent (head ^ "he") with
          | Some ((Bytes n as e), keep) ->
              Alcotest.(check (pair int bool)) "its bytes counted, kept" (String.length head + 5, true) (n, keep);
              Alcotest.(check (pair bool bool)) "whole when they are all there" (false, true) (Http.whole (head ^ "he") e, Http.whole (head ^ "hello") e)
          | _ -> Alcotest.fail "a Content-Length");
          (match Http.extent "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n5\r\nhello\r\n" with
          | Some ((Chunks _ as e), keep) ->
              Alcotest.(check bool) "the server closes" false keep;
              let so_far = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n5\r\nhello\r\n" in
              Alcotest.(check (pair bool bool)) "chunks: whole at the last, of size 0" (false, true) (Http.whole so_far e, Http.whole (so_far ^ "0\r\n\r\n") e)
          | _ -> Alcotest.fail "chunks");
          Alcotest.(check bool) "neither: to the connection's end" true
            (match Http.extent "HTTP/1.1 200 OK\r\n\r\nabc" with Some (To_the_end, _) -> true | _ -> false));
      Testo.create "Content-Encoding: gzip" (fun () ->
          Alcotest.(check string) "Content-Length, the compressed bytes'" "hi" (body_of [ "HTTP/1.1 200 OK"; "Content-Encoding: gzip"; "Content-Length: 25" ] (hi_gz ^ "more"));
          Alcotest.(check string) "until the connection closes; x-gzip" "hi" (body_of [ "HTTP/1.1 200 OK"; "content-encoding: X-GZIP" ] hi_gz);
          let chunked = Printf.sprintf "a\r\n%s\r\nf\r\n%s\r\n0\r\n\r\n" (String.sub hi_gz 0 10) (String.sub hi_gz 10 15) in
          Alcotest.(check string) "under the chunks" "hi" (body_of [ "HTTP/1.1 200 OK"; "Content-Encoding: gzip"; "Transfer-Encoding: chunked" ] chunked);
          Alcotest.(check string) "identity" "hi" (body_of [ "HTTP/1.1 200 OK"; "Content-Encoding: identity" ] "hi");
          Alcotest.(check string) "a 304 has no body to decompress" "" (body_of [ "HTTP/1.1 304 Not Modified"; "Content-Encoding: gzip" ] "");
          Alcotest.(check string) "a block of fixed codes" (String.make 24 'a')
            (body_of [ "HTTP/1.1 200 OK"; "Content-Encoding: gzip" ] "\x1f\x8b\x08\x00\x00\x00\x00\x00\x02\xff\x4b\x4c\xc4\x0e\x00\x84\x7a\x02\xe6\x18\x00\x00\x00");
          Alcotest.(check bool) "a coding we do not ask for" true
            (Result.is_error (Http.parse_response "HTTP/1.1 200 OK\r\nContent-Encoding: br\r\n\r\n..."));
          Alcotest.(check bool) "not a gzip stream" true
            (Result.is_error (Http.parse_response "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\n\r\n..."));
          Alcotest.(check bool) "a gzip stream cut short" true
            (Result.is_error (Http.parse_response ("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\n\r\n" ^ String.sub hi_gz 0 14))));
      Testo.create "the status line" (fun () ->
          Alcotest.(check (triple string int string)) "200" ("HTTP/1.1", 200, "OK") (ok (Http.parse_status_line "HTTP/1.1 200 OK"));
          Alcotest.(check (triple string int string))
            "a reason with spaces" ("HTTP/1.0", 404, "Not Found")
            (ok (Http.parse_status_line "HTTP/1.0 404 Not Found"));
          Alcotest.(check (triple string int string)) "no reason" ("HTTP/1.1", 204, "") (ok (Http.parse_status_line "HTTP/1.1 204"));
          Alcotest.(check bool) "not HTTP" true (Result.is_error (Http.parse_status_line "SSH-2.0-OpenSSH"));
          Alcotest.(check bool) "a 4-digit status" true (Result.is_error (Http.parse_status_line "HTTP/1.1 2000 OK")));
      Testo.create "the worked example: Wikipedia's chunked body" (fun () ->
          Alcotest.(check string) "joined" "Wikipedia in\r\n\r\nchunks." (ok (Http.dechunk wikipedia)));
      Testo.create "chunk extensions and trailers ignored" (fun () ->
          Alcotest.(check string) "joined" "Wikipedia"
            (ok (Http.dechunk "4;name=value\r\nWiki\r\n5\r\npedia\r\n0\r\nExpires: never\r\n\r\n")));
      Testo.create "a chunked body cut short" (fun () ->
          Alcotest.(check bool) "inside a chunk" true (Result.is_error (Http.dechunk "a\r\nWiki"));
          Alcotest.(check bool) "before the last chunk" true (Result.is_error (Http.dechunk "4\r\nWiki\r\n")));
      Testo.create "the four ways a body ends" (fun () ->
          Alcotest.(check string) "1. a 304 has none" "" (body_of [ "HTTP/1.1 304 Not Modified"; "Content-Length: 5" ] "hello");
          Alcotest.(check string) "2. chunked, before Content-Length" "Wikipedia in\r\n\r\nchunks."
            (body_of [ "HTTP/1.1 200 OK"; "Content-Length: 3"; "transfer-encoding: Chunked" ] wikipedia);
          Alcotest.(check string) "3. Content-Length" "hello" (body_of [ "HTTP/1.1 200 OK"; "content-length: 5" ] "hello, and more");
          Alcotest.(check string) "4. until closed" "hello, and more" (body_of [ "HTTP/1.1 200 OK" ] "hello, and more"));
      Testo.create "a body shorter than its Content-Length" (fun () ->
          Alcotest.(check bool) "truncated" true
            (Result.is_error (Http.parse_response "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nhello")));
      Testo.create "headers: case-insensitive, trimmed, lone LFs" (fun () ->
          let r = ok (Http.parse_response "HTTP/1.1 301 Moved\nLOCATION:   /new  \n\n") in
          Alcotest.(check (option string)) "Location" (Some "/new") (Http.header "Location" r.headers);
          Alcotest.(check bool) "a redirect" true (Http.is_redirect r.status));
      Testo.create "refused: folded headers, compression" (fun () ->
          Alcotest.(check bool) "folded" true
            (Result.is_error (Http.parse_response "HTTP/1.1 200 OK\r\nX-A: 1\r\n  2\r\n\r\n"));
          Alcotest.(check bool) "space before the colon" true
            (Result.is_error (Http.parse_response "HTTP/1.1 200 OK\r\nX-A : 1\r\n\r\n"));
          Alcotest.(check bool) "gzip" true
            (Result.is_error (Http.parse_response "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\n\r\n...")));
      Testo.create "the server's side: a request, whole or not yet" (fun () ->
          let show (p : Http.parsed_request) =
            match p with
            | Incomplete -> "incomplete"
            | Bad _ -> "bad"
            | Request (r, body, used) -> Printf.sprintf "%s %s body=%S used=%d" r.meth r.target body used
          in
          let check what s expected = Alcotest.(check string) what expected (show (Http.parse_request s)) in
          check "no empty line yet" "GET / HTTP/1.1\r\nHost: a\r\n" "incomplete";
          check "whole" "GET / HTTP/1.1\r\nHost: a\r\n\r\n" "GET / body=\"\" used=27";
          check "a body to come" "POST /f HTTP/1.1\r\nContent-Length: 3\r\n\r\nab" "incomplete";
          check "the body come, and more" "POST /f HTTP/1.1\r\nContent-Length: 3\r\n\r\nabcGET" "POST /f body=\"abc\" used=42";
          check "not a request line" "HELLO\r\n\r\n" "bad";
          check "a bad length" "POST / HTTP/1.1\r\nContent-Length: x\r\n\r\n" "bad");
      Testo.create "the server's side: a response, read back" (fun () ->
          let bytes = Http.response_to_string (Http.response 404 ~content_type:"text/html" "<p>no") in
          Alcotest.(check string)
            "the bytes"
            "HTTP/1.1 404 Not Found\r\nContent-Type: text/html\r\nContent-Length: 5\r\nConnection: close\r\n\r\n<p>no"
            bytes;
          let r = ok (Http.parse_response bytes) in
          Alcotest.(check (pair int string)) "parsed back" (404, "<p>no") (r.status, r.body));
    ]
