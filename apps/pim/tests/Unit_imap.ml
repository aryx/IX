(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_imap.mli *)

let str = Alcotest.(check string)
let strs = Alcotest.(check (list string))

(* a response read from text, as if it came over a connection *)
let read_text (s : string) : Imap.response option =
  let pos = ref 0 in
  let line () =
    if !pos >= String.length s then None
    else
      let e =
        match String.index_from_opt s !pos '\n' with
        | Some i -> i
        | None -> String.length s
      in
      let l = String.sub s !pos (e - !pos) in
      pos := e + 1;
      let n = String.length l in
      Some (if n > 0 && l.[n - 1] = '\r' then String.sub l 0 (n - 1) else l)
  in
  let bytes n =
    if !pos + n > String.length s then None
    else begin
      let b = String.sub s !pos n in
      pos := !pos + n;
      Some b
    end
  in
  Imap.read ~line ~bytes

let message = "Subject: lunch\r\n\r\nNoon at the usual place?\r\n"

(* the server's side of a socket, in a process of its own, until the
 * client logs out *)
let serve (fd : Unix.file_descr) (store : Imap_server.store) : unit =
  let conn = Lines.of_fd fd in
  let t, greeting = Imap_server.start () in
  List.iter (Lines.send_line conn) greeting;
  let rec go t =
    if not (Imap_server.ended t) then
      match Lines.line conn with
      | None -> ()
      | Some l ->
          let t, out = Imap_server.step store t l in
          List.iter (Lines.send_line conn) out;
          go t
  in
  go t;
  Lines.close conn

(* bob's mailbox: a question, its answer, and a newsletter archived *)
let mailbox () : Imap_server.store * (int -> Imap_server.message) =
  let ms =
    ref
      [
        {
          Imap_server.uid = 1;
          text =
            "From: Alice <alice@ix>\n\
             Subject: the plan\n\
             Message-ID: <1@ix>\n\n\
             see you\n";
          flags = [];
          labels = [ "\\Inbox" ];
        };
        {
          uid = 2;
          text =
            "From: Carol <carol@ix>\n\
             Subject: Re: the plan\n\
             Message-ID: <2@ix>\n\
             References: <1@ix>\n\n\
             yes\n";
          flags = [ "\\Seen" ];
          labels = [ "\\Inbox"; "travel" ];
        };
        {
          uid = 3;
          text = "From: news@ix\nSubject: weekly\n\nnews\n";
          flags = [];
          labels = [];
        };
      ]
  in
  ( {
      all_mail = "[Gmail]/All Mail";
      messages = (fun _ -> !ms);
      change =
        (fun _ uid ~flags ~labels ->
          ms :=
            List.map
              (fun (m : Imap_server.message) ->
                if m.uid = uid then { m with flags; labels } else m)
              !ms);
    },
    fun uid -> List.find (fun (m : Imap_server.message) -> m.uid = uid) !ms )

let tests =
  Testo.categorize "Imap"
    [
      Testo.create "the reader: a FETCH and its literal, statuses, a search"
        (fun () ->
          (match
             read_text
               (Printf.sprintf
                  "* 2 FETCH (UID 9 FLAGS (\\Seen) BODY[] {%d}\r\n%s)\r\n"
                  (String.length message) message)
           with
          | Some (Imap.Data [ Atom "2"; Atom "FETCH"; List items ]) ->
              let p = Imap.pairs items in
              str "UID" "9" (Imap.text (List.assoc "UID" p));
              Alcotest.(check bool)
                "FLAGS" true
                (List.assoc "FLAGS" p = Imap.List [ Atom "\\Seen" ]);
              str "the literal: the message" message
                (Imap.text (List.assoc "BODY[]" p))
          | _ -> Alcotest.fail "not a FETCH");
          Alcotest.(check bool)
            "an untagged OK, its code kept as text" true
            (read_text "* OK [UIDVALIDITY 3] UIDs valid\r\n"
            = Some (Imap.Status (None, "OK", "[UIDVALIDITY 3] UIDs valid")));
          Alcotest.(check bool)
            "tagged" true
            (read_text "a3 NO [AUTHENTICATIONFAILED] Invalid\r\n"
            = Some
                (Imap.Status (Some "a3", "NO", "[AUTHENTICATIONFAILED] Invalid"))
            );
          Alcotest.(check bool)
            "SEARCH" true
            (read_text "* SEARCH 4 9\r\n"
            = Some (Imap.Data [ Atom "SEARCH"; Atom "4"; Atom "9" ]));
          Alcotest.(check bool)
            "quoted, NIL, a bracketed atom" true
            (Imap.values "(\"a \\\"b\\\"\" NIL BODY[HEADER.FIELDS (FROM TO)])"
            = [
                Imap.List
                  [
                    String "a \"b\""; Nil; Atom "BODY[HEADER.FIELDS (FROM TO)]";
                  ];
              ]);
          str "quote" "\"a\\\\b\\\"\"" (Imap.quote "a\\b\"");
          str "a set of UIDs" "1:3,5,9:10" (Imap.uid_set [ 9; 2; 1; 3; 5; 10 ]));
      Testo.create "the client against mini-maild's machine" (fun () ->
          let store, _ = mailbox () in
          let ours, theirs = Unix.socketpair Unix.PF_UNIX Unix.SOCK_STREAM 0 in
          match Unix.fork () with
          | 0 ->
              Unix.close ours;
              serve theirs store;
              Unix._exit 0
          | pid ->
              Unix.close theirs;
              let get_ok = function Ok x -> x | Error e -> Alcotest.fail e in
              let t = get_ok (Imap.connect (Lines.of_fd ours)) in
              get_ok (Imap.login t ~user:"bob@ix" ~password:"x");
              str "UIDVALIDITY" "1" (get_ok (Imap.select t "INBOX"));
              Alcotest.(check (list int))
                "INBOX: the archived one not there" [ 1; 2 ]
                (get_ok (Imap.search t "ALL"));
              Alcotest.(check (list int))
                "UNSEEN" [ 1 ]
                (get_ok (Imap.search t "UNSEEN"));
              Alcotest.(check (list int))
                "X-GM-RAW" [ 2 ]
                (get_ok (Imap.search t "X-GM-RAW \"from:carol plan\""));
              (match get_ok (Imap.summaries t [ 1; 2 ]) with
              | [ a; b ] ->
                  Alcotest.(check (option string))
                    "headers" (Some "the plan")
                    (Mail.get a.headers "subject");
                  Alcotest.(check (option string))
                    "no body" (Some "") (Some a.headers.body);
                  strs "labels" [ "\\Inbox"; "travel" ] b.labels;
                  strs "flags" [ "\\Seen" ] b.flags;
                  str "one conversation" a.thread b.thread
              | l -> Alcotest.failf "%d summaries" (List.length l));
              str "the message, LF"
                "From: Alice <alice@ix>\n\
                 Subject: the plan\n\
                 Message-ID: <1@ix>\n\n\
                 see you\n"
                (get_ok (Imap.message t 1));
              Imap.logout t;
              ignore (Unix.waitpid [] pid));
      Testo.create "the server: read, archived, All Mail" (fun () ->
          let store, get = mailbox () in
          let t, _ = Imap_server.start () in
          let say t l = Imap_server.step store t l in
          let t, _ = say t "a1 LOGIN bob x" in
          let t, _ = say t "a2 SELECT INBOX" in
          let t, _ = say t "a3 UID FETCH 1 (BODY[])" in
          strs "BODY[] marks it read" [ "\\Seen" ] (get 1).flags;
          let t, out = say t "a4 UID STORE 1 -X-GM-LABELS (\\Inbox)" in
          strs "archived"
            [ "* 1 FETCH (UID 1 X-GM-LABELS ())"; "a4 OK STORE completed" ]
            out;
          let t, out = say t "a5 UID SEARCH ALL" in
          strs "out of INBOX" [ "* SEARCH 2"; "a5 OK SEARCH completed" ] out;
          let t, _ = say t "a6 SELECT \"[Gmail]/All Mail\"" in
          let _, out = say t "a7 UID SEARCH ALL" in
          strs "in All Mail" [ "* SEARCH 1 2 3"; "a7 OK SEARCH completed" ] out);
    ]
