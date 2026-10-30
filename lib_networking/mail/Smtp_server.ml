(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/networking/unix/Mail_server.ml,
 * its SMTP half (docs/plans/done/plan_mail.md); a pure machine, AUTH added *)

type delivery = { users : string list; mail : Mail.t }

(* what the client said so far of the message *)
type t = {
  domain : string;
  hello : string option;
  sender : string option;
  recipients : string list; (* the users of this domain *)
  data : string list option; (* the lines after DATA, the latest first *)
  quit : bool;
}

let start ~(domain : string) : t * string list =
  ( { domain; hello = None; sender = None; recipients = []; data = None;
      quit = false },
    Smtp.reply 220 [ domain ^ " ESMTP mini-maild" ] )

let ended (t : t) : bool = t.quit

(* "bob@ix" or "bob" is the user bob; mail for elsewhere is None *)
let local (t : t) (address : string) : string option =
  match String.index_opt address '@' with
  | None -> if address = "" then None else Some (String.lowercase_ascii address)
  | Some i ->
      let user = String.sub address 0 i
      and domain = String.sub address (i + 1) (String.length address - i - 1) in
      if String.lowercase_ascii domain = t.domain && user <> "" then
        Some (String.lowercase_ascii user)
      else None

(* the date, as a Date: header writes it, in Greenwich *)
let date_of (now : float) : Mail.date =
  let day, time = Clock.local ~offset:0 now in
  { day; time = { time with second = Float.of_int (int_of_float time.second) };
    offset = 0 }

(* the message taken, a Received: line on top *)
let deliver (t : t) (lines : string list) (now : float) : delivery =
  let mail = Mail.parse (Smtp.unstuff lines) in
  let from = match t.hello with Some h -> h | None -> "unknown" in
  let received =
    { Mail.name = "Received";
      raw = Printf.sprintf " from %s by %s with SMTP;\n  %s" from t.domain
          (Mail.date_to_string (date_of now)) }
  in
  { users = List.sort_uniq compare t.recipients;
    mail = { mail with fields = received :: mail.fields } }

let step (t : t) ~(now : float) (line : string) :
    t * string list * delivery option =
  let answer t code text = (t, Smtp.reply code [ text ], None) in
  match t.data with
  | Some lines when line = "." ->
      let d = deliver t (List.rev lines) now in
      ( { t with data = None; sender = None; recipients = [] },
        Smtp.reply 250 [ "OK: queued" ], Some d )
  | Some lines -> ({ t with data = Some (line :: lines) }, [], None)
  | None -> (
      match Smtp.parse_command line with
      | Helo d -> answer { t with hello = Some d } 250 t.domain
      | Ehlo d ->
          ( { t with hello = Some d },
            Smtp.reply 250
              [ Printf.sprintf "%s greets %s" t.domain d; "AUTH PLAIN" ],
            None )
      | Mail_from a ->
          answer { t with sender = Some a; recipients = [] } 250 "OK"
      | Rcpt_to a -> (
          if t.sender = None then answer t 503 "MAIL FROM first"
          else
            match local t a with
            | Some user ->
                answer { t with recipients = t.recipients @ [ user ] } 250 "OK"
            | None ->
                answer t 550
                  (Printf.sprintf "not a relay: %s is not for %s" a t.domain))
      | Data ->
          if t.recipients = [] then answer t 503 "RCPT TO first"
          else
            answer { t with data = Some [] } 354
              "End data with <CR><LF>.<CR><LF>"
      | Rset -> answer { t with sender = None; recipients = [] } 250 "OK"
      | Noop -> answer t 250 "OK"
      | Quit -> answer { t with quit = true } 221 "Bye"
      | Unknown l -> (
          (* the user and password with the command (the client's way,
           * Smtp.plain), any of them: a test's server *)
          match String.split_on_char ' ' l with
          | [ auth; plain; _ ]
            when String.uppercase_ascii auth = "AUTH"
                 && String.uppercase_ascii plain = "PLAIN" ->
              answer t 235 "2.7.0 Accepted"
          | _ -> answer t 500 "Command not recognized"))
