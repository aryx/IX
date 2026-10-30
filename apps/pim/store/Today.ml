(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Today.mli *)

type kind = At of int option | Late | Due | Back | From of string

let to_do (items : Item.t list) (today : Civil.date) : Item.t list =
  let t = Civil.days_from_civil today in
  let later (i : Item.t) =
    match Search.date (Item.field i "until") with
    | Some d -> Civil.days_from_civil d > t
    | None -> false
  in
  List.filter
    (fun i ->
      Item.has_stamp i "task" && Item.field i "done" = ""
      && Item.field i "someday" = "" && not (later i))
    items

let day (i : Item.t) : int =
  match Search.day i with Some d -> Civil.days_from_civil d | None -> max_int

let late (items : Item.t list) (today : Civil.date) : Item.t list =
  let t = Civil.days_from_civil today in
  List.filter (fun i -> day i < t) (to_do items today)

let due (items : Item.t list) (today : Civil.date) : Item.t list =
  let t = Civil.days_from_civil today in
  List.filter (fun i -> day i = t) (to_do items today)

(* a bill (a task with postings) says its amount *)
let task (i : Item.t) : string =
  match Books.postings i with
  | p :: _ -> Search.title i ^ "   " ^ Money.to_string (abs p.amount)
  | [] -> Search.title i

let from_people (items : Item.t list) ~(account : string) :
    (kind * string) list =
  List.filter_map
    (fun c ->
      match c with
      | (last : Imap.summary) :: _ when Conversations.unread c -> (
          match Mail.address (Item.field last.headers "from") with
          | Some a when People.who items a.mailbox <> None ->
              Some
                ( From (Conversations.who last.headers),
                  Conversations.header last.headers "subject" )
          | _ -> None)
      | _ -> None)
    (Conversations.group (Mail_item.listed items ~account ~mailbox:"INBOX"))

let lines (items : Item.t list) ~(account : string) (today : Civil.date) :
    (kind * string) list =
  List.map
    (fun (_, time, i) -> (At time, Search.title i))
    (Events.between items ~from:today ~upto:today)
  @ List.map (fun i -> (Late, task i)) (late items today)
  @ List.map (fun i -> (Due, task i)) (due items today)
  @ List.filter_map
      (fun i ->
        if Item.field i "woke" <> "" then Some (Back, Search.title i) else None)
      items
  @ from_people items ~account

let page (items : Item.t list) (today : Civil.date) : string list =
  match
    List.find_opt (fun i -> Item.id i = "day:" ^ Mail_sync.day today) items
  with
  | Some i ->
      List.filter (fun l -> String.trim l <> "") (String.split_on_char '\n' i.body)
  | None -> []

let again (i : Item.t) : Item.t option =
  match (Ics.rule_of_string (Item.field i "repeat"), Search.day i) with
  | Some r, Some due when Item.field i "repeat" <> "" -> (
      let d = Civil.days_from_civil due in
      match
        Recur.occurrences ~at:0 r ~start:due
          ~from:(Civil.civil_from_days (d + 1))
          ~upto:(Civil.civil_from_days (d + 400))
      with
      | next :: _ ->
          (* (the same id and its day: task:rent.2026-12-05) *)
          let base =
            let id = Item.id i and n = String.length (Item.id i) in
            if
              n > 11 && id.[n - 11] = '.'
              && Search.date (String.sub id (n - 10) 10) <> None
            then String.sub id 0 (n - 11)
            else id
          in
          let id = base ^ "." ^ Mail_sync.day next in
          Some
            (Mail.set "id" id
               (Mail.set "due" (Mail_sync.day next)
                  (Mail.remove "done" (Mail.remove "until" i))))
      | [] -> None)
  | _ -> None

