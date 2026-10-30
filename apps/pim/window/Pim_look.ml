(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Pim_look.mli *)

open Playground

type view = Home | Mail | Tasks | People
type go = View of view | Message of string | Write of string

let views =
  [ (Home, "Home"); (Mail, "Mail"); (Tasks, "Tasks"); (People, "People") ]

let menu_bar = 30.
let size = 16.
let row = 28.
let side = 170.
let bar = 40.

let ink = rgb 32 33 36
let grey = rgb 95 99 104
let blue = rgb 26 115 232
let red = rgb 197 34 31

let menu_box (computer : computer) (i : int) : Widget.box =
  let w = computer.screen.width and h = computer.screen.height in
  (* (as wide as the longest item, "Back to List  (u)") *)
  { Widget.x = (-.w /. 2.) +. 89. +. (float_of_int i *. 174.);
    y = (h /. 2.) -. (menu_bar /. 2.); w = 170.; h = menu_bar -. 4. }

let chosen (computer : computer) ~(first : int)
    (menus : (string * (string * 'c) list) list) : 'c option =
  List.fold_left
    (fun found (i, (title, items)) ->
      let labels = title :: List.map fst items in
      let k = Gui.menu_in computer (menu_box computer (first + i)) labels 0 in
      (* (0: the title, nothing chosen) *)
      if found <> None || k = 0 then found
      else Option.map snd (List.nth_opt items (k - 1)))
    None
    (List.mapi (fun i menu -> (i, menu)) menus)

(* a letter's width, Hershey's at [size] *)
let advance (c : string) : float =
  let g = Glyph_unicode.glyph c in
  float_of_int (g.right - g.left) *. size /. Hershey.units_per_em

let width (s : string) : float =
  List.fold_left (fun w c -> w +. advance c) 0. (Text.chars s)

let text (color : color) ~(bold : bool) ~(room : float) (x : float)
    (baseline : float) (s : string) : shape =
  let rec place (x0 : float) acc l =
    match l with
    | [] -> List.rev acc
    | c :: rest ->
        let w = advance c in
        if x0 +. w > x +. room then List.rev acc
        else place (x0 +. w) ((x0, c) :: acc) rest
  in
  letters color
    { size; bold; italic = false; baseline; at = place x [] (Text.chars s) }

let wrap (room : float) (s : string) : string list =
  List.concat_map
    (fun line ->
      let words = String.split_on_char ' ' line in
      let rec go cur acc ws =
        match ws with
        | [] -> List.rev (cur :: acc)
        | w :: rest ->
            let next = if cur = "" then w else cur ^ " " ^ w in
            if cur <> "" && width next > room then go w (cur :: acc) rest
            else go next acc rest
      in
      go "" [] words)
    (String.split_on_char '\n' s)

let title (i : Item.t) : string =
  match (Item.field i "subject", Item.field i "title", Item.field i "name") with
  | s, _, _ when s <> "" -> Mime.decode_words s
  | _, t, _ when t <> "" -> t
  | _, _, n when n <> "" -> n
  | _ -> (
      match String.split_on_char '\n' (String.trim i.body) with
      | l :: _ -> l
      | [] -> "")

let printable (typed : string) : string =
  String.concat "" (List.filter (fun c -> c >= " ") (Text.chars typed))

let without_last (s : string) : string =
  match List.rev (Text.chars s) with
  | [] -> ""
  | _ :: rest -> String.concat "" (List.rev rest)

type area = { left : float; top : float; x0 : float; room : float }

let area (computer : computer) : area =
  let w = computer.screen.width and h = computer.screen.height in
  let left = -.w /. 2. in
  (* (the menu bar above the rest) *)
  { left; top = (h /. 2.) -. menu_bar; x0 = left +. side +. 16.;
    room = w -. side -. 32. }

let title_bar (computer : computer) (title : string) (right : string) :
    shape list =
  let w = computer.screen.width in
  let a = area computer in
  [
    rectangle (rgb 241 243 244) w bar |> move 0. (a.top -. (bar /. 2.));
    text ink ~bold:true ~room:(w /. 2.) (a.left +. 16.) (a.top -. 26.) title;
    text grey ~bold:false ~room:(w /. 2.)
      (-.a.left -. 16. -. width right)
      (a.top -. 26.) right;
  ]

let row_y (a : area) (i : int) : float =
  a.top -. bar -. 12. -. (float_of_int i *. row) -. 19.

let selected (a : area) (y : float) : shape =
  rectangle (rgb 232 240 254) (a.room +. 16.) row
  |> move (a.x0 -. 8. +. ((a.room +. 16.) /. 2.)) (y +. 19. -. (row /. 2.))

let sidebar (a : area) (entries : (string * bool) list) : shape list =
  List.concat
    (List.mapi
       (fun i (name, shown) ->
         let y = row_y a i in
         (if shown then
            [ rectangle (rgb 211 227 253) side row
              |> move (a.left +. (side /. 2.)) (y +. 19. -. (row /. 2.)) ]
          else [])
         @ [ text ink ~bold:shown ~room:(side -. 24.) (a.left +. 16.) y name ])
       entries)

let count (n : int) (one : string) : string =
  let many =
    if n = 1 then one
    else if one = "person" then "people"
    else one ^ "s"
  in
  Printf.sprintf "%d %s" n many
