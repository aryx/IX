(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Found_window.mli *)

open Playground
open Pim_look

type caps = Mail_window.caps

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

(* a thing found, and the message it was found in *)
type row = {
  message : string; (* its item's id *)
  subject : string;
  from : string; (* the sender's address *)
  found : Detect.found;
  due : Civil.date option; (* the message's first day, a bill's *)
}

type model = {
  rows : row list;
  made : (int * string) list; (* a row made an item: its id *)
  selected : int;
  today : Civil.date;
  status : string;
  held : string Set_.t;
}

let store (caps : caps) : Items.t = Items.at (Items.place caps)

let initial (caps : caps) (flags : Playground.flags) : model =
  let today =
    match List.assoc_opt "today" flags with
    | Some d -> (
        match Search.date d with Some d -> d | None -> When.today caps)
    | None -> When.today caps
  in
  { rows = []; made = []; selected = 0; today; status = ""; held = Set_.empty }

let start (keys : string Set_.t) (m : model)
    (messages : (string * Mail.t) list) : model =
  let rows =
    List.concat_map
      (fun (id, mail) ->
        let found = Detect.find ~today:m.today (Mail_text.text mail) in
        let due =
          List.find_map
            (fun (f : Detect.found) ->
              match f.kind with Day (d, _) -> Some d | _ -> None)
            found
        in
        let from =
          match Mail.address (Conversations.header mail "from") with
          | Some a -> String.lowercase_ascii a.mailbox
          | None -> ""
        in
        List.map
          (fun f ->
            { message = id; subject = Conversations.header mail "subject";
              from; found = f; due })
          found)
      messages
  in
  { m with rows; made = []; selected = 0; status = ""; held = keys }

(*****************************************************************************)
(* What a row makes *)
(*****************************************************************************)

(* "Re: lunch" -> "lunch" *)
let topic (subject : string) : string =
  let rec go s =
    let low = String.lowercase_ascii s in
    let cut k = go (String.trim (String.sub s k (String.length s - k))) in
    if String.length s > 3 && String.sub low 0 3 = "re:" then cut 3
    else if String.length s > 4 && String.sub low 0 4 = "fwd:" then cut 4
    else s
  in
  let t = go (String.trim subject) in
  if t = "" then "(no subject)" else t

let made = ref 0

let fresh (kind : string) : string =
  incr made;
  Printf.sprintf "%s:%.0f.%d" kind (Unix.gettimeofday ()) !made

(* a row made an item, linked to its message by re:; the item's id and
 * what to say *)
let make (caps : caps) (r : row) : string * string =
  let items = Items.all caps (store caps) in
  match r.found.kind with
  | Day (day, time) ->
      let with_ =
        match People.who items r.from with
        | Some c -> [ Item.id c ]
        | None -> []
      in
      let e =
        Capture.to_item ~id:(fresh "event")
          { title = topic r.subject; day; time; repeat = ""; with_ }
      in
      let e = Mail.set "re" r.message e in
      Items.save caps (store caps) e;
      (Item.id e, "in the Calendar: " ^ title e)
  | Amount c ->
      let fields =
        [ ("title", "pay: " ^ topic r.subject); ("re", r.message);
          ( "posting",
            Printf.sprintf "Expenses:Bills  %d.%02d" (c / 100) (c mod 100) );
          ("posting", "Assets:Checking") ]
        @ match r.due with Some d -> [ ("due", Mail_sync.day d) ] | None -> []
      in
      let t =
        Item.make ~id:(fresh "task") ~stamps:[ "task"; "money" ] fields ""
      in
      Items.save caps (store caps) t;
      (Item.id t, "a bill to pay: " ^ Money.to_string c)
  | Address (name, a) -> (
      match People.who items a with
      | Some c -> (Item.id c, "")
      | None ->
          let c =
            Item.make
              ~id:(People.id { display = name; mailbox = a })
              ~stamps:[ "contact" ]
              [ ("name", if name = "" then a else name); ("email", a) ]
              ""
          in
          Items.save caps (store caps) c;
          (Item.id c, "in People: " ^ title c))

(*****************************************************************************)
(* The keys *)
(*****************************************************************************)

type command = Make | Next | Previous | Back

let menus : (string * (string * command) list) list =
  [ ( "Found",
      [ ("Keep It  (Enter)", Make); ("Next  (j)", Next);
        ("Previous  (k)", Previous); ("Back to the Message  (Esc)", Back) ] )
  ]

let command (caps : caps) (m : model) (c : command) : model * go option =
  match c with
  | Next ->
      let last = List.length m.rows - 1 in
      ({ m with selected = max 0 (min last (m.selected + 1)) }, None)
  | Previous -> ({ m with selected = max 0 (m.selected - 1) }, None)
  | Back -> (m, Some (View Mail))
  | Make -> (
      match
        (List.assoc_opt m.selected m.made, List.nth_opt m.rows m.selected)
      with
      | Some id, _ -> (m, Some (Item id))
      | None, Some r ->
          let id, said = make caps r in
          (* (a contact already there: opened) *)
          if said = "" then (m, Some (Item id))
          else ({ m with made = (m.selected, id) :: m.made; status = said }, None)
      | None, None -> (m, None))

let update (caps : caps) (computer : computer) (m : model) : model * go option =
  let keys = computer.keyboard.keys in
  let pressed name = Set_.mem name keys && not (Set_.mem name m.held) in
  let key =
    if Gui.modal () then None
    else if pressed "j" || pressed "ArrowDown" then Some Next
    else if pressed "k" || pressed "ArrowUp" then Some Previous
    else if pressed "Enter" || pressed "o" then Some Make
    else if pressed "Escape" || pressed "u" then Some Back
    else None
  in
  let m, go =
    match (chosen computer ~first:1 menus, key) with
    | Some c, _ | None, Some c -> command caps m c
    | None, None when wheel computer <> 0 ->
        ( { m with
            selected = moved m.selected (wheel computer) (List.length m.rows) },
          None )
    | None, None -> (m, None)
  in
  ({ m with held = keys }, go)

(*****************************************************************************)
(* The picture *)
(*****************************************************************************)

let view (computer : computer) (m : model) : shape list =
  let a = area computer in
  let kind (r : row) =
    match r.found.kind with
    | Day (d, t) ->
        ( "day",
          Civil.to_string d
          ^ match t with Some t -> " " ^ Events.clock t | None -> "" )
    | Amount c -> ("amount", Money.to_string c)
    | Address (n, a) -> ("address", if n = "" then a else n ^ " <" ^ a ^ ">")
  in
  let main =
    if m.rows = [] then
      [ text grey ~bold:false ~room:a.room a.x0 (row_y a 0)
          "Nothing found in this message: no day, amount or address." ]
    else
      List.concat
        (List.mapi
           (fun i (r : row) ->
             let y = row_y a (2 * i) in
             let what, read = kind r in
             (if i = m.selected then
                [ selected a y; selected a (y -. row) ]
              else [])
             @ [ text grey ~bold:false ~room:80. a.x0 y what;
                 text ink ~bold:true ~room:250. (a.x0 +. 90.) y r.found.said;
                 text blue ~bold:false ~room:(a.room -. 380.) (a.x0 +. 360.) y
                   ((if List.mem_assoc i m.made then "\xe2\x9c\x93 " else "")
                    ^ read);
                 text grey ~bold:false ~room:(a.room -. 90.) (a.x0 +. 90.)
                   (y -. row) r.found.line ])
           m.rows)
  in
  let right =
    if m.status <> "" then m.status
    else
      match List.nth_opt m.rows m.selected with
      | Some _ when List.mem_assoc m.selected m.made ->
          "Enter: open what was made"
      | Some r -> (
          match r.found.kind with
          | Day _ -> "Enter: an event"
          | Amount _ -> "Enter: a bill"
          | Address _ -> "Enter: a contact")
      | None -> ""
  in
  let subject = match m.rows with r :: _ -> topic r.subject | [] -> "" in
  (rectangle white computer.screen.width computer.screen.height
   :: title_bar computer ("Found in: " ^ subject) right)
  @ sidebar a [ (count (List.length m.rows) "thing" ^ " found", true) ]
  @ main
