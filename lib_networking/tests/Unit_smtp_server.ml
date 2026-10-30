(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_smtp_server.mli *)

let str = Alcotest.(check string)
let lines = Alcotest.(check (list string))

(* the client and the server, each the other's lines, until the client
 * is done; the deliveries *)
let session (c : Smtp.client) : Smtp.client * Smtp_server.delivery list =
  let s, greeting = Smtp_server.start ~domain:"ix" in
  let rec go c s (from_server : string list) delivered =
    match from_server with
    | [] -> (c, List.rev delivered)
    | l :: rest ->
        let c, sent = Smtp.step c l in
        let s, answers, delivered =
          List.fold_left
            (fun (s, answers, delivered) l ->
              let s, a, d = Smtp_server.step s ~now:0. l in
              let delivered =
                match d with Some d -> d :: delivered | None -> delivered
              in
              (s, answers @ a, delivered))
            (s, [], delivered) sent
        in
        go c s (rest @ answers) delivered
  in
  go c s greeting []

let message =
  Mail.make
    [ ("From", "alice@ix"); ("To", "Bob <bob@ix>, carol@elsewhere");
      ("Bcc", "dave@ix"); ("Subject", "lunch") ]
    "Noon?\n.a line with a dot\n"

let tests =
  Testo.categorize "Smtp_server"
    [
      Testo.create "Smtp's client against it: delivered, Bcc: gone, the dot back"
        (fun () ->
          let e = Smtp.envelope ~sender:"alice@ix" message in
          let c, delivered =
            session (Smtp.client ~hello:"pim" ~auth:(Some ("alice", "x")) [ e ])
          in
          (match Smtp.finished c with
          | Some (Ok [ Smtp.Sent (2, [ refused ]) ]) ->
              Alcotest.(check bool) "the relay refused" true
                (String.starts_with ~prefix:"550" refused)
          | _ -> Alcotest.fail "not sent to two");
          match delivered with
          | [ d ] ->
              lines "to bob and dave" [ "bob"; "dave" ] d.users;
              str "the body" "Noon?\n.a line with a dot\n" d.mail.body;
              Alcotest.(check (option string)) "no Bcc:" None
                (Mail.get d.mail "bcc");
              Alcotest.(check (option string)) "Received: on top"
                (Some "from pim by ix with SMTP;  Thu, 1 Jan 1970 00:00:00 +0000")
                (match d.mail.fields with
                 | f :: _ when f.name = "Received" ->
                     Some (String.trim (Mail.unfold f.raw))
                 | _ -> None)
          | l -> Alcotest.failf "%d deliveries" (List.length l));
      Testo.create "commands out of order" (fun () ->
          let s, _ = Smtp_server.start ~domain:"ix" in
          let said s l = let s, a, _ = Smtp_server.step s ~now:0. l in (s, a) in
          let s, a = said s "RCPT TO:<bob@ix>" in
          lines "RCPT before MAIL" [ "503 MAIL FROM first" ] a;
          let s, a = said s "DATA" in
          lines "DATA before RCPT" [ "503 RCPT TO first" ] a;
          let s, a = said s "QUIT" in
          lines "bye" [ "221 Bye" ] a;
          Alcotest.(check bool) "ended" true (Smtp_server.ended s));
      Testo.create "Lines: CR LF taken off, lines in pieces, talk" (fun () ->
          let ours, theirs = Unix.socketpair Unix.PF_UNIX Unix.SOCK_STREAM 0 in
          let conn = Lines.of_fd ours in
          (* the server's side, written before: in pieces, cut anywhere *)
          List.iter (Tcp.send_all theirs)
            [ "220 ix\r"; "\n250-ix greets pim\r\n250 AUTH"; " PLAIN\r\n";
              "221 Bye\r\n" ];
          let c = Smtp.client ~hello:"pim" ~auth:None [] in
          let c = Lines.talk conn Smtp.step c (fun c -> Smtp.finished c <> None) in
          Alcotest.(check bool) "done" true (Smtp.finished c = Some (Ok []));
          Lines.close conn;
          str "what it sent, CR LF each" "EHLO pim\r\nQUIT\r\n"
            (Tcp.receive_all theirs));
    ]
