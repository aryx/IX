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

let place (items : Item.t list) ~(account : string)
    (c : Imap.summary list) : place =
  let me = String.lowercase_ascii account in
  (* the newest message not the account's own *)
  match List.find_opt (fun s -> address s <> me) c with
  | None -> Imbox
  | Some s -> (
      let a = address s in
      match List.find_opt (fun i -> Item.id i = sender_id a) items with
      | Some d -> (
          match Item.field d "screen" with
          | "feed" -> Feed
          | "paper" -> Paper
          | "out" -> Out
          | _ -> Imbox)
      | None -> (
          if People.who items a <> None then Imbox
          else
            match since items with
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
