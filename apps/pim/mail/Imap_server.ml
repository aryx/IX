(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Imap_server.mli *)

type message = {
  uid : int;
  text : string;
  flags : string list;
  labels : string list;
}

type store = {
  all_mail : string;
  messages : string -> message list;
  change : string -> int -> flags:string list -> labels:string list -> unit;
}

type t = { user : string option; mailbox : string option; logout : bool }

let start () : t * string list =
  ( { user = None; mailbox = None; logout = false },
    [ "* OK [CAPABILITY IMAP4rev1 X-GM-EXT-1] mini-maild ready" ] )

let ended (t : t) : bool = t.logout
(* the messages of the mailbox selected *)
let mailbox (store : store) (user : string) (name : string) : message list =
  let l = store.messages user in
  if name = store.all_mail then l
  else List.filter (fun m -> List.mem "\\Inbox" m.labels) l

(* "1:3,5,7:*": the UIDs in it, [top] the largest there is *)
let in_set (set : string) (top : int) (uid : int) : bool =
  let n s = if s = "*" then Some top else int_of_string_opt s in
  List.exists
    (fun part ->
      match String.split_on_char ':' part with
      | [ a ] -> n a = Some uid
      | [ a; b ] -> (
          match (n a, n b) with
          | Some a, Some b -> uid >= min a b && uid <= max a b
          | _ -> false)
      | _ -> false)
    (String.split_on_char ',' set)

(* the wire's text: CR LF *)
let crlf (s : string) : string =
  String.concat "\r\n" (String.split_on_char '\n' s)

let literal (s : string) : string =
  Printf.sprintf "{%d}\r\n%s" (String.length s) s

let list = Imap.list

(* each message's conversation: the UID of the first of its thread *)
let threads (all : message list) : (int * int) list =
  List.concat_map
    (fun tree ->
      let ms = List.map fst (Mail_thread.flatten [ tree ]) in
      let first =
        List.fold_left (fun a (m : message) -> min a m.uid) max_int ms
      in
      List.map (fun (m : message) -> (m.uid, first)) ms)
    (Mail_thread.of_mail (fun (m : message) -> Mail.parse m.text) all)

let contains (s : string) (word : string) : bool =
  let s = String.lowercase_ascii s and w = String.lowercase_ascii word in
  let n = String.length s and k = String.length w in
  let rec at i = i + k <= n && (String.sub s i k = w || at (i + 1)) in
  at 0

(* X-GM-RAW's words, each found: in From:, in Subject:, or anywhere *)
let raw_match (m : message) (query : string) : bool =
  let mail = Mail.parse m.text in
  let field name = match Mail.get mail name with Some v -> v | None -> "" in
  List.for_all
    (fun w ->
      match String.index_opt w ':' with
      | Some i when List.mem (String.sub w 0 i) [ "from"; "subject" ] ->
          contains
            (field (String.sub w 0 i))
            (String.sub w (i + 1) (String.length w - i - 1))
      | _ -> contains m.text w)
    (List.filter (fun w -> w <> "") (String.split_on_char ' ' query))

let rec matches (m : message) (criteria : Imap.value list) : bool =
  match criteria with
  | [] -> true
  | Imap.Atom a :: rest when String.uppercase_ascii a = "ALL" -> matches m rest
  | Imap.Atom a :: rest when String.uppercase_ascii a = "SEEN" ->
      List.mem "\\Seen" m.flags && matches m rest
  | Imap.Atom a :: rest when String.uppercase_ascii a = "UNSEEN" ->
      (not (List.mem "\\Seen" m.flags)) && matches m rest
  | Imap.Atom a :: q :: rest when String.uppercase_ascii a = "X-GM-RAW" ->
      raw_match m (Imap.text q) && matches m rest
  | _ -> false

(* "BODY[HEADER.FIELDS (FROM SUBJECT)]"'s names, in lower case *)
let field_names (item : string) : string list =
  match (String.index_opt item '(', String.index_opt item ')') with
  | Some i, Some j when j > i ->
      List.map String.lowercase_ascii
        (List.filter
           (fun s -> s <> "")
           (String.split_on_char ' ' (String.sub item (i + 1) (j - i - 1))))
  | _ -> []

(* an item of a FETCH answered, and whether it marks the message read;
 * None for an item not known *)
let fetch_item (m : message) (thread : int) (item : string) :
    (string * bool) option =
  let mail = Mail.parse m.text in
  let headers (fields : Mail.field list) =
    crlf (Mail.to_string { Mail.fields; body = "" })
  in
  match String.uppercase_ascii item with
  | "UID" -> Some ("UID " ^ string_of_int m.uid, false)
  | "FLAGS" -> Some ("FLAGS " ^ list m.flags, false)
  | "X-GM-LABELS" -> Some ("X-GM-LABELS " ^ list m.labels, false)
  | "X-GM-THRID" -> Some ("X-GM-THRID " ^ string_of_int thread, false)
  | "X-GM-MSGID" -> Some ("X-GM-MSGID " ^ string_of_int m.uid, false)
  | "RFC822.SIZE" ->
      Some ("RFC822.SIZE " ^ string_of_int (String.length (crlf m.text)), false)
  | "BODY[]" -> Some ("BODY[] " ^ literal (crlf m.text), true)
  | "BODY.PEEK[]" -> Some ("BODY[] " ^ literal (crlf m.text), false)
  | "BODY[HEADER]" | "BODY.PEEK[HEADER]" ->
      Some ("BODY[HEADER] " ^ literal (headers mail.fields), false)
  | i
    when String.starts_with ~prefix:"BODY.PEEK[HEADER.FIELDS " i
         || String.starts_with ~prefix:"BODY[HEADER.FIELDS " i ->
      let names = field_names item in
      let fields =
        List.filter
          (fun (f : Mail.field) ->
            List.mem (String.lowercase_ascii f.name) names)
          mail.fields
      in
      let key =
        "BODY["
        ^ String.sub item
            (String.index item '[' + 1)
            (String.length item - String.index item '[' - 1)
      in
      Some
        ( key ^ " " ^ literal (headers fields),
          String.starts_with ~prefix:"BODY[" i )
  | _ -> None

let seen (flags : string list) : string list =
  if List.mem "\\Seen" flags then flags else flags @ [ "\\Seen" ]

(* a STORE's change of a list: set, added to, taken from *)
let changed (op : string) (old : string list) (given : string list) :
    string list =
  match op.[0] with
  | '+' -> old @ List.filter (fun x -> not (List.mem x old)) given
  | '-' -> List.filter (fun x -> not (List.mem x given)) old
  | _ -> given

(* UID FETCH set items: each message of the set, its items *)
let fetch (store : store) (user : string) (name : string) (tag : string)
    (args : Imap.value list) : string list =
  match args with
  | set :: items :: _ ->
      let items =
        match items with
        | Imap.List l -> List.map Imap.text l
        | v -> [ Imap.text v ]
      in
      (* the UID always, first *)
      let items =
        "UID" :: List.filter (fun i -> String.uppercase_ascii i <> "UID") items
      in
      let ms = mailbox store user name in
      let top = List.fold_left (fun a (m : message) -> max a m.uid) 0 ms in
      let thread = threads (store.messages user) in
      let answer (seq : int) (m : message) : string option option =
        if not (in_set (Imap.text set) top m.uid) then Some None
        else
          let t =
            match List.assoc_opt m.uid thread with Some t -> t | None -> m.uid
          in
          let parts = List.map (fetch_item m t) items in
          if List.mem None parts then None
          else
            let parts = List.filter_map (fun p -> p) parts in
            if List.exists snd parts && not (List.mem "\\Seen" m.flags) then
              store.change user m.uid ~flags:(seen m.flags) ~labels:m.labels;
            Some
              (Some
                 (Printf.sprintf "* %d FETCH (%s)" seq
                    (String.concat " " (List.map fst parts))))
      in
      let answers = List.mapi (fun i m -> answer (i + 1) m) ms in
      if List.mem None answers then [ tag ^ " BAD an item not known" ]
      else
        List.filter_map
          (fun a -> match a with Some a -> a | None -> None)
          answers
        @ [ tag ^ " OK FETCH completed" ]
  | _ -> [ tag ^ " BAD UID FETCH set items" ]

(* UID STORE set item (values): FLAGS or X-GM-LABELS, set (no sign),
 * added (+) or taken off (-), the new ones answered unless .SILENT *)
let change (store : store) (user : string) (name : string) (tag : string)
    (args : Imap.value list) : string list =
  match args with
  | [ set; what; Imap.List given ] ->
      let what = String.uppercase_ascii (Imap.text what) in
      let silent = String.ends_with ~suffix:".SILENT" what in
      let given = List.map Imap.text given in
      let ms = mailbox store user name in
      let top = List.fold_left (fun a (m : message) -> max a m.uid) 0 ms in
      let signed = what <> "" && (what.[0] = '+' || what.[0] = '-') in
      let field =
        if signed then String.sub what 1 (String.length what - 1) else what
      in
      let labels = String.starts_with ~prefix:"X-GM-LABELS" field in
      if not (labels || String.starts_with ~prefix:"FLAGS" field) then
        [ tag ^ " BAD STORE FLAGS or X-GM-LABELS" ]
      else
        let one (i : int) (m : message) : string list =
          if not (in_set (Imap.text set) top m.uid) then []
          else
            let flags =
              if labels then m.flags else changed what m.flags given
            in
            let lbls =
              if labels then changed what m.labels given else m.labels
            in
            store.change user m.uid ~flags ~labels:lbls;
            if silent then []
            else
              [
                Printf.sprintf "* %d FETCH (UID %d %s %s)" (i + 1) m.uid
                  (if labels then "X-GM-LABELS" else "FLAGS")
                  (list (if labels then lbls else flags));
              ]
        in
        List.concat (List.mapi one ms) @ [ tag ^ " OK STORE completed" ]
  | _ -> [ tag ^ " BAD UID STORE set item (values)" ]

let step (store : store) (t : t) (line : string) : t * string list =
  let vs = Imap.values line in
  match vs with
  | [] -> (t, [ "* BAD empty command" ])
  | tag :: rest -> (
      let tag = Imap.text tag in
      let ok text = tag ^ " OK " ^ text and no text = tag ^ " NO " ^ text in
      let verb, args =
        match rest with
        | v :: args -> (String.uppercase_ascii (Imap.text v), args)
        | [] -> ("", [])
      in
      let verb, args =
        match (verb, args) with
        | "UID", v :: args ->
            ("UID " ^ String.uppercase_ascii (Imap.text v), args)
        | _ -> (verb, args)
      in
      match (verb, t.user, t.mailbox) with
      | "CAPABILITY", _, _ ->
          (t, [ "* CAPABILITY IMAP4rev1 X-GM-EXT-1"; ok "CAPABILITY completed" ])
      | "NOOP", _, _ -> (t, [ ok "NOOP completed" ])
      | "LOGOUT", _, _ ->
          ( { t with logout = true },
            [ "* BYE mini-maild"; ok "LOGOUT completed" ] )
      | "LOGIN", _, _ -> (
          match args with
          | [ user; _ ] ->
              (* "bob@ix" is bob *)
              let u = String.lowercase_ascii (Imap.text user) in
              let u =
                match String.index_opt u '@' with
                | Some i -> String.sub u 0 i
                | None -> u
              in
              ({ t with user = Some u }, [ ok "LOGIN completed" ])
          | _ -> (t, [ tag ^ " BAD LOGIN user password" ]))
      | _, None, _ -> (t, [ no "LOGIN first" ])
      | "LIST", Some _, _ ->
          ( t,
            [
              "* LIST (\\HasNoChildren) \"/\" \"INBOX\"";
              "* LIST (\\All \\HasNoChildren) \"/\" " ^ Imap.quote store.all_mail;
              ok "LIST completed";
            ] )
      | ("SELECT" | "EXAMINE"), Some user, _ -> (
          match args with
          | [ name ] ->
              let name = Imap.text name in
              let name =
                if String.uppercase_ascii name = "INBOX" then "INBOX" else name
              in
              if name <> "INBOX" && name <> store.all_mail then
                (t, [ no ("no mailbox " ^ name) ])
              else
                let ms = mailbox store user name in
                let next =
                  List.fold_left (fun a (m : message) -> max a (m.uid + 1)) 1 ms
                in
                ( { t with mailbox = Some name },
                  [
                    "* FLAGS (\\Seen \\Answered \\Flagged \\Deleted \\Draft)";
                    Printf.sprintf "* %d EXISTS" (List.length ms);
                    "* OK [UIDVALIDITY 1] UIDs valid";
                    Printf.sprintf "* OK [UIDNEXT %d] the next UID" next;
                    ok ("[READ-WRITE] " ^ verb ^ " completed");
                  ] )
          | _ -> (t, [ tag ^ " BAD " ^ verb ^ " mailbox" ]))
      | _, _, None -> (t, [ no "SELECT first" ])
      | "UID SEARCH", Some user, Some name ->
          let uids =
            List.filter_map
              (fun (m : message) ->
                if matches m args then Some (string_of_int m.uid) else None)
              (mailbox store user name)
          in
          (t, [ String.concat " " ("* SEARCH" :: uids); ok "SEARCH completed" ])
      | "UID FETCH", Some user, Some name -> (t, fetch store user name tag args)
      | "UID STORE", Some user, Some name -> (t, change store user name tag args)
      | _ -> (t, [ tag ^ " BAD command not known: " ^ verb ]))
