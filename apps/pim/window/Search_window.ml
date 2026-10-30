(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Search_window.mli *)

open Playground
open Pim_look

type caps = Mail_window.caps

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

type model = {
  back : view; (* the view searched from, Esc's *)
  items : Item.t list; (* the store as it was when the search began *)
  query : string;
  (* the items found, by view, in the views' order *)
  found : (view * Item.t list) list;
  only : view option; (* Tab: one view's, else every one's *)
  selected : int;
  today : Civil.date;
  held : string Set_.t;
}

(* where an item opens (Pim_window.go's order: a message that is a task
 * too is a message) *)
let lives (i : Item.t) : view option =
  List.find_map
    (fun (stamp, v) -> if Item.has_stamp i stamp then Some v else None)
    [ ("message", Mail); ("contact", People); ("task", Tasks);
      ("event", Calendar); ("note", Notes); ("money", Money) ]

let day (i : Item.t) : int =
  match Search.day i with Some d -> Civil.days_from_civil d | None -> min_int

(* the newest first where an item has a day (mail, events, money), else
 * by title *)
let order (v : view) (l : Item.t list) : Item.t list =
  match v with
  | Mail | Calendar | Money ->
      List.stable_sort (fun a b -> compare (day b) (day a)) l
  | _ ->
      List.stable_sort
        (fun a b ->
          compare (String.lowercase_ascii (title a))
            (String.lowercase_ascii (title b)))
        l

let find (m : model) : model =
  let hits =
    if String.trim m.query = "" then [] else Search.search m.query m.items
  in
  let found =
    List.filter_map
      (fun (v, _) ->
        match List.filter (fun i -> lives i = Some v) hits with
        | [] -> None
        | l -> Some (v, order v l))
      views
  in
  let only =
    match m.only with
    | Some v when List.mem_assoc v found -> m.only
    | _ -> None
  in
  { m with found; only; selected = 0 }

(* the rows shown: a view's name, then its items *)
type row = Heading of view * int | Found of Item.t

let rows (m : model) : row list =
  List.concat_map
    (fun (v, l) ->
      if m.only = None || m.only = Some v then
        Heading (v, List.length l) :: List.map (fun i -> Found i) l
      else [])
    m.found

let results (m : model) : Item.t list =
  List.filter_map (fun r -> match r with Found i -> Some i | _ -> None) (rows m)

let initial (caps : caps) (flags : Playground.flags) : model =
  let today =
    match List.assoc_opt "today" flags with
    | Some d -> (
        match Search.date d with Some d -> d | None -> When.today caps)
    | None -> When.today caps
  in
  ignore caps;
  { back = Home; items = []; query = ""; found = []; only = None;
    selected = 0; today; held = Set_.empty }

let start (caps : caps) (keys : string Set_.t) (m : model) (back : view) :
    model =
  find
    { m with back; items = Items.all caps (Items.at (Items.place caps));
      query = ""; only = None; held = keys }

(*****************************************************************************)
(* What the keys and the menus do *)
(*****************************************************************************)

type command = Open_ | Next | Previous | Next_view | Close

let menus : (string * (string * command) list) list =
  [ ( "Search",
      [ ("Open  (Enter)", Open_); ("Next  (Down)", Next);
        ("Previous  (Up)", Previous); ("Next Component  (Tab)", Next_view);
        ("Close  (Esc)", Close) ] ) ]

let command (m : model) (c : command) : model * go option =
  let n = List.length (results m) in
  match c with
  | Open_ -> (
      match List.nth_opt (results m) m.selected with
      | Some i -> (m, Some (Item (Item.id i)))
      | None -> (m, None))
  | Next -> ({ m with selected = max 0 (min (n - 1) (m.selected + 1)) }, None)
  | Previous -> ({ m with selected = max 0 (m.selected - 1) }, None)
  | Next_view ->
      (* every view's, then each one's in turn, then every view's again *)
      let vs = List.map fst m.found in
      let rec after l =
        match l with
        | v :: (w :: _ as rest) -> if Some v = m.only then Some w else after rest
        | _ -> None
      in
      let only =
        match (m.only, vs) with
        | None, v :: _ -> Some v
        | None, [] -> None
        | Some _, _ -> after vs
      in
      ({ m with only; selected = 0 }, None)
  | Close -> (m, Some (View m.back))

(* how many rows fit under the title bar, and the first shown *)
let fits (computer : computer) : int =
  let a = area computer in
  let bottom = (-.computer.screen.height /. 2.) +. 40. in
  int_of_float ((a.top -. bar -. 12. -. bottom) /. row)

let first (computer : computer) (m : model) : int =
  (* the selected item's row, headings counted *)
  let rec at k j l =
    match l with
    | [] -> 0
    | Heading _ :: rest -> at (k + 1) j rest
    | Found _ :: rest -> if j = m.selected then k else at (k + 1) (j + 1) rest
  in
  max 0 (at 0 0 (rows m) - fits computer + 1)

(* the item clicked, if one was *)
let click (computer : computer) (m : model) : Item.t option =
  let a = area computer in
  let mouse = computer.mouse in
  if (not mouse.mclick) || mouse.mx < a.x0 || Gui.modal () then None
  else
    let top = row_y a 0 +. row -. 9. in
    let k = int_of_float ((top -. mouse.my) /. row) + first computer m in
    if mouse.my > top then None
    else
      match List.nth_opt (rows m) k with Some (Found i) -> Some i | _ -> None

let update (caps : caps) (computer : computer) (m : model) : model * go option
    =
  ignore caps;
  let keys = computer.keyboard.keys in
  let pressed name = Set_.mem name keys && not (Set_.mem name m.held) in
  let key =
    if pressed "ArrowDown" then Some Next
    else if pressed "ArrowUp" then Some Previous
    else if pressed "Enter" then Some Open_
    else if pressed "Tab" then Some Next_view
    else if pressed "Escape" then Some Close
    else None
  in
  let m, go =
    match (chosen computer ~first:1 menus, key, click computer m) with
    | Some c, _, _ | None, Some c, _ -> command m c
    | None, None, Some i -> (m, Some (Item (Item.id i)))
    | None, None, None when Gui.modal () -> (m, None)
    | None, None, None ->
        (* the query as it is typed, the items found at each letter *)
        if pressed "Backspace" then
          (find { m with query = without_last m.query }, None)
        else
          let typed = printable computer.keyboard.typed in
          if typed = "" then (m, None)
          else (find { m with query = m.query ^ typed }, None)
  in
  ({ m with held = keys }, go)

(*****************************************************************************)
(* The picture *)
(*****************************************************************************)

(* what is said after an item's title: who and when, a day, an address *)
let detail (today : Civil.date) (i : Item.t) : string =
  let date =
    match Search.day i with
    | Some d when d = today -> "today"
    | Some d -> Civil.to_string d
    | None -> ""
  in
  match lives i with
  | Some Mail -> Conversations.who i ^ "   " ^ date
  | Some Calendar -> Item.field i "when"
  | Some People -> Item.field i "email"
  | Some Tasks ->
      if Item.field i "done" <> "" then "done"
      else if Item.field i "due" <> "" then "due " ^ date
      else ""
  | Some Money -> (
      match Books.postings i with
      | p :: _ -> date ^ "   " ^ Money.to_string (abs p.amount)
      | [] -> date)
  | Some Notes -> (
      match String.split_on_char '\n' (String.trim i.body) with
      | l :: _ -> l
      | [] -> "")
  | Some Home | None -> ""

let view (computer : computer) (m : model) : shape list =
  let a = area computer in
  let n = List.length (results m) in
  let name v = List.assoc v views in
  let main =
    if String.trim m.query = "" then
      List.mapi
        (fun k l -> text grey ~bold:false ~room:a.room a.x0 (row_y a k) l)
        [ "Type to search every component: mail, events, people, tasks,";
          "notes, money. Words match any field or the text;";
          "from:alice  is:task  label:travel  before:2026-12-01  -is:read";
          "";
          "Up and Down choose, Enter opens it where it lives, Tab one";
          "component's, Esc back." ]
    else if n = 0 then
      [ text grey ~bold:false ~room:a.room a.x0 (row_y a 0)
          ("Nothing matches " ^ m.query ^ " in the store.") ]
    else
      let first = first computer m in
      let rec draw k j l =
        match l with
        | [] -> []
        | r :: rest when k < first ->
            draw (k + 1) (match r with Found _ -> j + 1 | _ -> j) rest
        | _ when k - first >= fits computer -> []
        | Heading (v, c) :: rest ->
            text ink ~bold:true ~room:a.room a.x0 (row_y a (k - first))
              (Printf.sprintf "%s (%d)" (name v) c)
            :: draw (k + 1) j rest
        | Found i :: rest ->
            let y = row_y a (k - first) in
            (if j = m.selected then [ selected a y ] else [])
            @ [ text ink ~bold:false ~room:330. (a.x0 +. 16.) y (title i);
                text grey ~bold:false ~room:(a.room -. 360.) (a.x0 +. 360.) y
                  (detail m.today i) ]
            @ draw (k + 1) (j + 1) rest
      in
      draw 0 0 (rows m)
  in
  (rectangle white computer.screen.width computer.screen.height
   :: title_bar computer ("search: " ^ m.query ^ "_") (count n "item"))
  @ sidebar a
      (("Everything", m.only = None)
       :: List.map
            (fun (v, l) ->
              (Printf.sprintf "%s  %d" (name v) (List.length l), m.only = Some v))
            m.found)
  @ main
