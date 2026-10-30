(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Screen.mli *)

type place = Imbox | Screener | Feed | Paper | Out

let setting = "setting:screener"

let since (items : Item.t list) : string option =
  match List.find_opt (fun i -> Item.id i = setting) items with
  | Some i when Item.field i "since" <> "" -> Some (Item.field i "since")
  | _ -> None

let turn_on (today : Civil.date) : Item.t =
  Item.make ~id:setting ~stamps:[ "setting" ]
    [ ("since", Civil.to_string today) ]
    ""

let sender_id (address : string) : string =
  "sender:" ^ String.lowercase_ascii address

let name (p : place) : string =
  match p with
  | Imbox -> "imbox"
  | Screener -> "screener"
  | Feed -> "feed"
  | Paper -> "paper"
  | Out -> "out"

let decide (address : string) (p : place) : Item.t =
  Item.make ~id:(sender_id address) ~stamps:[ "sender" ]
    [ ("email", String.lowercase_ascii address); ("screen", name p) ]
    ""

let address (s : Imap.summary) : string =
  match Mail.address (Item.field s.headers "from") with
  | Some a -> String.lowercase_ascii a.mailbox
  | None -> ""

let place (items : Item.t list) ~(account : string) :
    Imap.summary list -> place =
  (* (read once, then each conversation a lookup: a store of thousands
   * of messages read again at each list's load) *)
  let decided = Hashtbl.create 64 in
  let known = Hashtbl.create 256 in
  List.iter
    (fun i ->
      if Item.has_stamp i "sender" then
        Hashtbl.replace decided
          (String.lowercase_ascii (Item.field i "email"))
          (Item.field i "screen")
      else if Item.has_stamp i "contact" then
        List.iter (fun e -> Hashtbl.replace known e ()) (People.emails i))
    items;
  let on = since items in
  let me = String.lowercase_ascii account in
  fun (c : Imap.summary list) ->
    (* the newest message not the account's own *)
    match List.find_opt (fun s -> address s <> me) c with
    | None -> Imbox
    | Some s -> (
        let a = address s in
        match Hashtbl.find_opt decided a with
        | Some "feed" -> Feed
        | Some "paper" -> Paper
        | Some "out" -> Out
        | Some _ -> Imbox
        | None -> (
            if Hashtbl.mem known a then Imbox
            else
              match on with
              | None -> Imbox
              | Some day ->
                  (* (who wrote before the Screener was on is let in) *)
                  let before =
                    List.exists
                      (fun s ->
                        address s = a && Conversations.day s.headers < day)
                      c
                  in
                  if before then Imbox else Screener))
