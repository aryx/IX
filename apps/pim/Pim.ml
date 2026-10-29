(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-pim from a terminal (docs/plans/plan_pim.md: "the same store
 * from a terminal, for real use and for the tests"). Its first
 * command, of the mail's stage 2 (plan_mail.md):
 *
 *     mini-pim send [-s host:port] [-plain] [-u user] file
 *
 * the message in [file] sent by SMTP to whom its To:, Cc: and Bcc:
 * say (Smtp.envelope), from its From:. By default to Gmail
 * (smtp.gmail.com:465, TLS from the first byte), as -u, the whole
 * address, with an app password (plan_mail.md: Google's one exception
 * to OAuth), read from the first line of standard input and never
 * written anywhere. -plain: no TLS, for mini-maild on this machine.
 * Each message's outcome is a line on standard output. *)

type caps = < Cap.network; Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

let usage = "usage: mini-pim send [-s host:port] [-plain] [-u user] file
  -s      the SMTP server (smtp.gmail.com:465)
  -plain  no TLS (mini-maild, on this machine)
  -u      log in as that user, the password the first line of stdin"

type send = {
  host : string;
  port : int;
  plain : bool;
  user : string option;
  file : string;
}

let rec send_options (o : send) (args : string list) : send option =
  match args with
  | [] -> if o.file = "" then None else Some o
  | "-s" :: hp :: rest -> (
      match String.rindex_opt hp ':' with
      | Some i -> (
          let port = String.sub hp (i + 1) (String.length hp - i - 1) in
          match int_of_string_opt port with
          | Some port ->
              send_options { o with host = String.sub hp 0 i; port } rest
          | None -> None)
      | None -> send_options { o with host = hp } rest)
  | "-plain" :: rest -> send_options { o with plain = true } rest
  | "-u" :: u :: rest -> send_options { o with user = Some u } rest
  | flag :: _ when String.length flag > 1 && flag.[0] = '-' -> None
  | file :: rest -> send_options { o with file } rest

let send (caps : < caps; .. >) (o : send) : Exit.t =
  let mail = Mail.parse (FS.read caps (Fpath.v o.file)) in
  let sender =
    match Option.bind (Mail.get mail "from") Mail.address with
    | Some a -> a.mailbox
    | None -> ( match o.user with Some u -> u | None -> "")
  in
  let auth =
    match o.user with
    | None -> None
    | Some u -> (
        match In_channel.input_line (Console.stdin caps) with
        | Some p -> Some (u, String.trim p)
        | None -> None)
  in
  let conn =
    if o.plain then Lines.plain caps ~host:o.host ~port:o.port
    else
      Lines.tls caps ~trust:(Tls_client.system_roots caps) ~host:o.host
        ~port:o.port
  in
  match conn with
  | Error why ->
      Console.eprint caps (Printf.sprintf "%s:%d: %s\n" o.host o.port why);
      Exit.Err "connect"
  | Ok conn -> (
      let c =
        Smtp.client ~hello:"mini-pim" ~auth [ Smtp.envelope ~sender mail ]
      in
      let c = Lines.talk conn Smtp.step c (fun c -> Smtp.finished c <> None) in
      let why = Lines.why conn in
      Lines.close conn;
      match Smtp.finished c with
      | Some (Ok outcomes) ->
          List.iter
            (fun o ->
              Console.print caps
                (match (o : Smtp.outcome) with
                 | Sent (n, []) -> Printf.sprintf "sent to %d\n" n
                 | Sent (n, refused) ->
                     Printf.sprintf "sent to %d, refused: %s\n" n
                       (String.concat "; " refused)
                 | Refused why -> "refused: " ^ why ^ "\n"))
            outcomes;
          if List.for_all (function Smtp.Sent _ -> true | _ -> false) outcomes
          then Exit.OK
          else Exit.Err "refused"
      | Some (Error said) ->
          Console.eprint caps ("the server: " ^ said ^ "\n");
          Exit.Err "smtp"
      | None ->
          Console.eprint caps
            ((match why with Some w -> w | None -> "the connection ended")
            ^ "\n");
          Exit.Err "smtp")

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  match List.tl (Array.to_list argv) with
  | "send" :: args -> (
      let default =
        { host = "smtp.gmail.com"; port = 465; plain = false; user = None;
          file = "" }
      in
      match send_options default args with
      | Some o -> send caps o
      | None -> Console.eprint caps (usage ^ "\n"); Exit.Err "usage")
  | _ -> Console.eprint caps (usage ^ "\n"); Exit.Err "usage"

let () =
  Cap.main (fun caps ->
      Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
