(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Notes_window.mli *)

open Playground
open Pim_look

type caps = Mail_window.caps

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

type shown = Notes | Days
type mode = Browsing | Editing | Asking

type model = {
  shown : shown;
  notes : Item.t list; (* the list shown's *)
  selected : int;
  mode : mode;
  (* the note open, its text being edited, what it names and what names
   * it (-> and <-) *)
  note : Item.t option;
  body : Text_edit.t;
  links : (bool * Item.t) list;
  today : Civil.date;
  field : string; (* a new note's title, typed *)
  status : string;
  held : string Set_.t;
}

let store (caps : caps) : Items.t = Items.at (Items.place caps)

let is_day (i : Item.t) : bool =
  String.length (Item.id i) > 4 && String.sub (Item.id i) 0 4 = "day:"

(* the notes by title; the days, the last first *)
let load (caps : caps) (m : model) : model =
  let items = Items.all caps (store caps) in
  let notes = List.filter (fun i -> Item.has_stamp i "note") items in
  let l =
    match m.shown with
    | Notes ->
        List.stable_sort
          (fun a b ->
            compare (String.lowercase_ascii (title a))
              (String.lowercase_ascii (title b)))
          (List.filter (fun i -> not (is_day i)) notes)
    | Days ->
        List.rev
          (List.stable_sort
             (fun a b -> compare (Item.id a) (Item.id b))
             (List.filter is_day notes))
  in
  let links =
    match m.note with
    | None -> []
    | Some n ->
        List.map (fun (_, i) -> (true, i)) (Links.links items n)
        @ List.map (fun (_, i) -> (false, i)) (Links.backlinks items n)
  in
  { m with notes = l; links;
    selected = max 0 (min m.selected (List.length l - 1)) }

let initial (caps : caps) (flags : Playground.flags) : model =
  let today =
    match List.assoc_opt "today" flags with
    | Some d -> (
        match Search.date d with Some d -> d | None -> When.today caps)
    | None -> When.today caps
  in
  load caps
    { shown = Notes; notes = []; selected = 0; mode = Browsing; note = None;
      body = Text_edit.of_string ""; links = []; today; field = "";
      status = ""; held = Set_.empty }

let refresh (caps : caps) (keys : string Set_.t) (m : model) : model =
  load caps { m with held = keys }

(* the note opened, to be written in *)
let edit (caps : caps) (m : model) (n : Item.t) : model =
  load caps
    { m with mode = Editing; note = Some n; body = Text_edit.of_string n.body;
      shown = (if is_day n then Days else Notes); status = "" }

let show (caps : caps) (m : model) (id : string) : model =
  match Items.find caps (store caps) id with
  | Some n -> edit caps m n
  | None -> { m with status = id ^ ": not in the store" }

(* "The Plan, again" -> "the-plan-again", an id a person can type
 * between [[ ]]; made unique by a number *)
let slug (caps : caps) (t : string) : string =
  let s =
    String.concat "-"
      (List.filter (fun w -> w <> "")
         (String.split_on_char ' '
            (String.map
               (fun c ->
                 match c with
                 | 'a' .. 'z' | '0' .. '9' -> c
                 | 'A' .. 'Z' -> Char.lowercase_ascii c
                 | _ -> ' ')
               t)))
  in
  let s = if s = "" then "note" else s in
  let rec free k =
    let id = if k = 1 then "note:" ^ s else Printf.sprintf "note:%s-%d" s k in
    if Items.find caps (store caps) id = None then id else free (k + 1)
  in
  free 1

(* today's page, made when first asked (plan_pim.md, stage 7: the
 * daily note) *)
let day_note (caps : caps) (m : model) : model =
  let id = "day:" ^ Mail_sync.day m.today in
  match Items.find caps (store caps) id with
  | Some n -> edit caps m n
  | None ->
      let n =
        Item.make ~id ~stamps:[ "note" ]
          [ ("title", Mail_sync.day m.today) ]
          ""
      in
      Items.save caps (store caps) n;
      edit caps m n

(*****************************************************************************)
(* What the keys and the menus do *)
(*****************************************************************************)

type command =
  | New_
  | Today
  | Open_
  | Back
  | Next
  | Previous
  | Notes_list
  | Days_list

let menus : (string * (string * command) list) list =
  [ ( "Note",
      [ ("New Note...  (n)", New_); ("Today's Note  (d)", Today);
        ("Open  (o)", Open_); ("Back to List  (Esc)", Back);
        ("Next  (j)", Next); ("Previous  (k)", Previous) ] );
    ("List", [ ("Notes  (Tab)", Notes_list); ("Days  (Tab)", Days_list) ]) ]

let command (caps : caps) (m : model) (c : command) : model =
  match c with
  | New_ -> { m with mode = Asking; field = ""; status = "" }
  | Today -> day_note caps m
  | Open_ -> (
      match List.nth_opt m.notes m.selected with
      | Some n when m.mode = Browsing -> edit caps m n
      | _ -> m)
  | Back -> load caps { m with mode = Browsing; note = None }
  | Next when m.mode = Browsing ->
      { m with selected = min (List.length m.notes - 1) (m.selected + 1) }
  | Previous when m.mode = Browsing ->
      { m with selected = max 0 (m.selected - 1) }
  | Next | Previous -> m
  | Notes_list ->
      load caps { m with shown = Notes; selected = 0; mode = Browsing;
                  note = None }
  | Days_list ->
      load caps { m with shown = Days; selected = 0; mode = Browsing;
                  note = None }

(* where the text is, and the links under it *)
let links_shown = 5

let area_box (computer : computer) : Widget.box =
  let a = area computer in
  let top = a.top -. bar -. 10. in
  let bottom =
    (-.computer.screen.height /. 2.) +. 20. +. (float_of_int links_shown *. row)
  in
  { Widget.x = a.x0 +. (a.room /. 2.); y = (top +. bottom) /. 2.; w = a.room;
    h = top -. bottom }

let link_y (computer : computer) (k : int) : float =
  (-.computer.screen.height /. 2.) +. 14.
  +. (float_of_int (links_shown - 1 - k) *. row)

(* the link clicked under the text, if one was *)
let link_click (computer : computer) (m : model) : Item.t option =
  let a = area computer in
  let mouse = computer.mouse in
  if (not mouse.mclick) || mouse.mx < a.x0 || Gui.modal () then None
  else
    List.find_map
      (fun (k, (_, i)) ->
        let y = link_y computer k in
        if mouse.my >= y && mouse.my < y +. row then Some i else None)
      (List.filteri (fun k _ -> k < links_shown)
         (List.mapi (fun k l -> (k, l)) m.links))

let update (caps : caps) (computer : computer) (m : model) : model * go option =
  let keys = computer.keyboard.keys in
  let pressed name = Set_.mem name keys && not (Set_.mem name m.held) in
  let menu = chosen computer ~first:1 menus in
  let m, go =
    match m.mode with
    | Asking ->
        if pressed "Escape" then ({ m with mode = Browsing; field = "" }, None)
        else if pressed "Enter" then
          let t = String.trim m.field in
          if t = "" then ({ m with mode = Browsing }, None)
          else begin
            let n =
              Item.make ~id:(slug caps t) ~stamps:[ "note" ] [ ("title", t) ] ""
            in
            Items.save caps (store caps) n;
            (edit caps { m with field = "" } n, None)
          end
        else if pressed "Backspace" then
          ({ m with field = without_last m.field }, None)
        else ({ m with field = m.field ^ printable computer.keyboard.typed }, None)
    | Editing -> (
        (* the text written to the store as it changes, the Palm's way *)
        let body = Gui.text_area_in computer (area_box computer) m.body in
        let m =
          match m.note with
          | Some n when Text_edit.to_string body <> n.body ->
              let n = { n with body = Text_edit.to_string body } in
              Items.save caps (store caps) n;
              load caps { m with note = Some n; body }
          | _ -> { m with body }
        in
        match (menu, link_click computer m) with
        | Some c, _ -> (command caps m c, None)
        (* (a note opened here, the rest where it lives) *)
        | None, Some i when Item.has_stamp i "note" -> (edit caps m i, None)
        | None, Some i -> (m, Some (Item (Item.id i)))
        | None, None ->
            if pressed "Escape" then (command caps m Back, None) else (m, None))
    | Browsing when Gui.modal () -> (m, None)
    | Browsing -> (
        let key =
          if pressed "j" || pressed "ArrowDown" then Some Next
          else if pressed "k" || pressed "ArrowUp" then Some Previous
          else if pressed "o" || pressed "Enter" then Some Open_
          else if pressed "n" then Some New_
          else if pressed "d" then Some Today
          else if pressed "Tab" then
            Some (if m.shown = Notes then Days_list else Notes_list)
          else None
        in
        let side_ =
          match sidebar_click computer with
          | Some 0 -> Some Notes_list
          | Some 1 -> Some Days_list
          | _ -> None
        in
        let clicked =
          match row_click computer with
          | Some i when i < List.length m.notes -> Some i
          | _ -> None
        in
        match (menu, key, side_, clicked) with
        | Some c, _, _, _ | None, Some c, _, _ | None, None, Some c, _ ->
            (command caps m c, None)
        | None, None, None, Some i ->
            (command caps { m with selected = i } Open_, None)
        | None, None, None, None -> (m, None))
  in
  ({ m with held = keys }, go)

(*****************************************************************************)
(* The picture *)
(*****************************************************************************)

(* "note", "contact", "mail": what an item is, by its id *)
let kind (i : Item.t) : string =
  match String.index_opt (Item.id i) ':' with
  | Some k -> String.sub (Item.id i) 0 k
  | None -> ""

let view (computer : computer) (m : model) : shape list =
  let a = area computer in
  let title_ =
    match (m.mode, m.note) with
    | Asking, _ -> "a note: " ^ m.field ^ "_"
    | Editing, Some n -> title n
    | _ -> if m.shown = Notes then "Notes" else "Days"
  in
  let right =
    if m.status <> "" then m.status
    else
      match (m.mode, m.note) with
      | Editing, Some n -> Item.id n
      | _ -> count (List.length m.notes) (if m.shown = Notes then "note" else "day")
  in
  let main =
    match m.mode with
    | Editing ->
        (* the text is the toolkit's (Gui.draw); the links under it *)
        if m.links = [] then
          [ text grey ~bold:false ~room:a.room a.x0 (link_y computer 0 +. 9.)
              "No links: [[contact:alice]] or [[note:the-plan]] in the text \
               makes one." ]
        else
          List.mapi
            (fun k (out, i) ->
              text (if out then blue else grey) ~bold:false ~room:a.room a.x0
                (link_y computer k +. 9.)
                ((if out then "\xe2\x86\x92 " else "\xe2\x86\x90 ")
                 ^ title i ^ "   (" ^ kind i ^ ")"))
            (List.filteri (fun k _ -> k < links_shown) m.links)
    | _ when m.notes = [] ->
        [ text grey ~bold:false ~room:a.room a.x0 (row_y a 0)
            (if m.shown = Notes then "No notes: n writes one."
             else "No days: d writes today's.") ]
    | _ ->
        List.concat
          (List.mapi
             (fun i (n : Item.t) ->
               let y = row_y a i in
               let first =
                 match String.split_on_char '\n' (String.trim n.body) with
                 | l :: _ -> l
                 | [] -> ""
               in
               (if i = m.selected then [ selected a y ] else [])
               @ [ text ink ~bold:false ~room:240. a.x0 y (title n);
                   text grey ~bold:false ~room:(a.room -. 250.) (a.x0 +. 250.)
                     y first ])
             m.notes)
  in
  (rectangle white computer.screen.width computer.screen.height
   :: title_bar computer title_ right)
  @ sidebar a [ ("Notes", m.shown = Notes); ("Days", m.shown = Days) ]
  @ main
