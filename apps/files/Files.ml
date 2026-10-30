(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-files: folders in a window, and a file opened by a double click
 * or Enter without knowing which program reads it
 * (docs/plans/done/plan_files.md):
 *
 *   /  home  pad  docs                   <- the path, the parents a click away
 *   Name                  Size       Day <- a click: sorted by it, again:
 *   games/                     2026-10-30   the other way
 *  #report.pdf#####     1.2 MB 2026-10-29#
 *   song.mod             31 KB 2026-10-02
 *   application/pdf: page                <- what Enter will do
 *
 *   the file's first bytes --File_kind--> application/pdf
 *                                               | ~/.mailcap, the built-in
 *                                               v rules (Helpers)
 *                                         page /home/pad/docs/report.pdf
 *                                               |
 *                                               v a window of its own
 *
 * Folder says what a directory holds and the history of this kind of
 * program. A file's kind is a read of 4,096 bytes: for its icon, asked of
 * the rows on the screen and of a few of them a frame (a big folder does
 * not stop the window), never of a whole folder.
 *
 * A window of its own under mini-rio, and on Linux a process beside; on
 * mini-9pi's bare screen a program would fight this one for the screen
 * and the mouse: the status line asks for rio first (Helpers.run). *)

open Playground

type caps =
  < Cap.readdir ; Cap.open_in ; Cap.open_out ; Cap.env ; Cap.exec ; Cap.wait ; Cap.exit ; Cap.argv ; Cap.stdout ; Cap.stderr
  ; Cap.draw ; Cap.mouse ; Cap.keyboard ; Cap.fork >

let usage =
  "usage: mini-files [dir] [root=dir]    a folder in a window (root=: not above it)\n\
   in the window:\n\
  \  up, down, the wheel         the selection, the list moved\n\
  \  Enter, a double click       a folder entered, a file opened by its program\n\
  \  Backspace                   the folder above;  b  the one before\n\
  \  a click on the path         that folder\n\
  \  a click on Name, Size, Day  sorted by it; again, the other way\n\
  \  .                           the names that begin with a dot, shown or not\n\
  \  c, x, then v                copied or cut, put in the folder shown\n\
  \  a row dragged on a folder   moved there (the path's folders too)\n\
  \  r                           renamed;  n  a new folder\n\
  \  d                           deleted, after a question\n\
  \  q                           the end\n"

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

(* what the status line asks, the keys meanwhile being for it *)
type asking = Deleting | Renaming | New_folder

(* c or x: nothing changes until v, in the folder then shown *)
type clip = Copied of string | Cut of string

(* the button down on a row: where, and which entry *)
type press = { row_pressed : int; px : float; py : float }

type model = {
  root : string; (* no folder above it is shown *)
  dir : string;
  entries : Folder.entry array; (* in the order shown *)
  kinds : string option array; (* of the entries: known once they were on the screen *)
  order : Folder.order;
  reversed : bool;
  dots : bool; (* the names that begin with a dot, shown *)
  selected : int;
  top : int; (* the first row shown *)
  before : string list; (* the folders left, the last first *)
  said : string; (* the status line, when an action said something *)
  asking : asking option;
  field : string; (* what is typed after the question *)
  clip : clip option;
  press : press option;
  button_held : bool; (* last frame's: a press is the frame it goes down *)
  rules : Helpers.rule list; (* read once *)
  kind : string; (* the selected file's, and its program's name *)
  last_click : (int * float) option; (* the row, when: for a double click *)
  held : string Set_.t;
}

(*****************************************************************************)
(* Reading the folder *)
(*****************************************************************************)

let selected_entry (m : model) : Folder.entry option =
  if m.selected >= 0 && m.selected < Array.length m.entries then Some m.entries.(m.selected) else None

(* the rule for the selected file, and what it is *)
let rule_of (caps : caps) (m : model) (e : Folder.entry) : string * Helpers.rule option =
  let path = Folder.join m.dir e.name in
  if Sys_plan9.is_device caps path then ("a pipe or a device", None)
  else
    match File_kind.of_path caps (Fpath.v path) with
    | kind -> (kind, Helpers.for_type m.rules kind)
    | exception Sys_error why -> (why, None)

let with_kind (caps : caps) (m : model) : model =
  match selected_entry m with
  | Some e when not e.is_dir ->
      let kind, rule = rule_of caps m e in
      { m with kind = (match rule with Some r -> kind ^ ": " ^ Helpers.name r | None -> kind) }
  | _ -> { m with kind = "" }

let with_selected (caps : caps) (m : model) (i : int) : model =
  let n = Array.length m.entries in
  let i = max 0 (min i (n - 1)) in
  if i = m.selected then m else with_kind caps { m with selected = i; said = "" }

(* the folder read again, the same name selected if it is still there *)
let read (caps : caps) (m : model) (selected : string option) : model =
  match Folder.list caps m.dir with
  | exception Unix.Unix_error (e, _, _) ->
      { m with entries = [||]; kinds = [||]; selected = 0; top = 0; kind = ""; said = m.dir ^ ": " ^ Unix.error_message e }
  | all ->
      let shown = if m.dots then all else List.filter (fun (e : Folder.entry) -> e.name.[0] <> '.') all in
      let entries = Array.of_list (Folder.sort m.order ~reversed:m.reversed shown) in
      let rec find (i : int) =
        if i >= Array.length entries then 0 else if Some entries.(i).name = selected then i else find (i + 1)
      in
      with_kind caps { m with entries; kinds = Array.make (Array.length entries) None; selected = find 0; top = 0 }

(* the folder one comes up to: selected what one came from *)
let came_from (dir : string) (old : string) : string option =
  let prefix = Folder.join dir "" in
  if String.starts_with ~prefix old then
    let rest = String.sub old (String.length prefix) (String.length old - String.length prefix) in
    Some (List.hd (String.split_on_char '/' rest))
  else None

let enter (caps : caps) (m : model) (dir : string) : model =
  if dir = m.dir then m
  else read caps { m with dir; before = m.dir :: m.before; said = "" } (came_from dir m.dir)

let initial (caps : caps) (root : string) (dir : string) : model =
  read caps
    { root; dir; entries = [||]; kinds = [||]; order = By_name; reversed = false; dots = false; selected = 0; top = 0;
      before = []; said = ""; asking = None; field = ""; clip = None; press = None; button_held = false; rules = Helpers.rules caps; kind = ""; last_click = None; held = Set_.empty }
    None

let open_selected (caps : caps) (m : model) : model =
  match selected_entry m with
  | None -> m
  | Some e when e.is_dir -> enter caps m (Folder.join m.dir e.name)
  | Some e -> (
      let path = Folder.join m.dir e.name in
      match rule_of caps m e with
      | kind, None -> { m with said = Printf.sprintf "no program for %s" kind }
      | _, Some rule ->
          if not (Helpers.windows ()) then { m with said = Helpers.name rule ^ ": start rio first, for its window" }
          else (
            Helpers.run caps (Helpers.command rule ~url:path ~file:(Some path));
            { m with said = Printf.sprintf "%s given to %s" e.name (Helpers.name rule) }))

(*****************************************************************************)
(* The layout *)
(*****************************************************************************)

let size = 16.
let row = 24.
let path_bar = 30.
let status_bar = 26.
let icon_room = 22.

let ink = rgb 32 33 36
let grey = rgb 95 99 104
let bars = rgb 232 234 237
let chosen = rgb 26 115 232
let target = rgb 200 225 250

let advance (c : string) : float =
  let g = Glyph_unicode.glyph c in
  float_of_int (g.right - g.left) *. size /. Hershey.units_per_em

let width (s : string) : float = List.fold_left (fun w c -> w +. advance c) 0. (Text.chars s)

(* [s] from [x], cut at [room] *)
let text (color : color) ~(bold : bool) ~(room : float) (x : float) (baseline : float) (s : string) : shape =
  let rec place (x0 : float) acc l =
    match l with
    | [] -> List.rev acc
    | c :: rest ->
        let w = advance c in
        if x0 +. w > x +. room then List.rev acc else place (x0 +. w) ((x0, c) :: acc) rest
  in
  letters color { size; bold; italic = false; baseline; at = place x [] (Text.chars s) }

(* what is measured from the screen: the columns' left ends, the rows *)
type area = { left : float; right : float; top_y : float; size_x : float; day_x : float; rows : int }

let area (computer : computer) : area =
  let w = computer.screen.width and h = computer.screen.height in
  let left = (-.w /. 2.) +. 8. and right = (w /. 2.) -. 8. in
  { left; right; top_y = h /. 2.;
    size_x = right -. 225.;
    day_x = right -. 125.;
    rows = max 1 (int_of_float ((h -. path_bar -. status_bar -. row) /. row)) }

(* the row's middle *)
let row_y (a : area) (i : int) : float = a.top_y -. path_bar -. row -. (row /. 2.) -. (float_of_int i *. row)

(* the row under a height, on the screen *)
let row_at (a : area) (y : float) : int option =
  let from_top = a.top_y -. path_bar -. row -. y in
  if from_top < 0. then None
  else
    let i = int_of_float (from_top /. row) in
    if i < a.rows then Some i else None

(* the buttons of the path: the name, the folder, where it begins *)
let path_buttons (a : area) (m : model) : (string * string * float) list =
  let _, l =
    List.fold_left
      (fun (x, acc) (name, path) -> (x +. width name +. 18., (name, path, x) :: acc))
      (a.left, [])
      (Folder.parents ~root:m.root m.dir)
  in
  List.rev l

let keep_shown (a : area) (m : model) : model =
  if m.selected < m.top then { m with top = m.selected }
  else if m.selected >= m.top + a.rows then { m with top = m.selected - a.rows + 1 }
  else m

(*****************************************************************************)
(* The update *)
(*****************************************************************************)

let sorted (caps : caps) (m : model) (order : Folder.order) : model =
  let reversed = m.order = order && not m.reversed in
  let name = Option.map (fun (e : Folder.entry) -> e.name) (selected_entry m) in
  read caps { m with order; reversed } name

(*****************************************************************************)
(* Changing files *)
(*****************************************************************************)

(* the action's failure, in words *)
let tried (action : unit -> unit) : string option =
  match action () with
  | () -> None
  | exception Folder.Refused why -> Some why
  | exception Unix.Unix_error (e, _, what) -> Some (Filename.basename what ^ ": " ^ Unix.error_message e)
  | exception Sys_error why -> Some why

(* the folder read again after an action, what it said on the status line *)
let shown (caps : caps) (a : area) (m : model) (name : string option) (said : string) : model =
  keep_shown a { (read caps m name) with said; asking = None; field = "" }

let selected_name (m : model) : string option = Option.map (fun (e : Folder.entry) -> e.name) (selected_entry m)

(* the row that takes a deleted one's place *)
let next_name (m : model) : string option =
  let n = Array.length m.entries in
  if m.selected + 1 < n then Some m.entries.(m.selected + 1).name
  else if m.selected > 0 then Some m.entries.(m.selected - 1).name
  else None

let delete (caps : caps) (a : area) (m : model) : model =
  match selected_entry m with
  | None -> m
  | Some e -> (
      match tried (fun () -> Folder.remove caps (Folder.join m.dir e.name)) with
      | None -> shown caps a m (next_name m) (e.name ^ " deleted")
      | Some why -> shown caps a m (Some e.name) why)

(* the field, a name of one folder, given to the action *)
let named (caps : caps) (a : area) (m : model) (action : string -> unit) (said : string -> string) : model =
  let name = m.field in
  if not (Folder.good_name name) then
    { m with said = "a name is not empty, and has no / in it"; asking = None; field = "" }
  else
    match tried (fun () -> action name) with
    | None -> shown caps a m (Some name) (said name)
    | Some why -> shown caps a m (selected_name m) why

let copy_or_cut (m : model) (clip : string -> clip) (word : string) : model =
  match selected_entry m with
  | None -> m
  | Some e ->
      { m with
        clip = Some (clip (Folder.join m.dir e.name));
        said = Printf.sprintf "%s %s: v in the folder it goes to" e.name word }

let paste (caps : caps) (a : area) (m : model) : model =
  let here (from : string) = Filename.dirname from = m.dir in
  match m.clip with
  | None -> { m with said = "nothing to put here: c or x first" }
  | Some (Cut from) when here from -> { m with said = Filename.basename from ^ " is already here" }
  | Some (Cut from) -> (
      let name = Filename.basename from in
      match tried (fun () -> Folder.move caps from (Folder.join m.dir name)) with
      | None -> shown caps a { m with clip = None } (Some name) (name ^ " moved here")
      | Some why -> shown caps a m (selected_name m) why)
  | Some (Copied from) -> (
      let base = Filename.basename from in
      let taken (name : string) = Folder.exists caps (Folder.join m.dir name) in
      let name = if here from then Folder.copy_name ~taken base else base in
      match tried (fun () -> Folder.copy caps from (Folder.join m.dir name)) with
      | None -> shown caps a m (Some name) (name ^ " copied here")
      | Some why -> shown caps a m (selected_name m) why)

(* while a question is on the status line: y alone deletes *)
let answer (caps : caps) (computer : computer) (a : area) (m : model) (q : asking) : model =
  let keys = computer.keyboard.keys in
  let pressed (name : string) = Set_.mem name keys && not (Set_.mem name m.held) in
  let typed = computer.keyboard.typed in
  let dropped = { m with asking = None; field = ""; said = "" } in
  match q with
  | Deleting -> if typed = "y" then delete caps a m else if typed = "n" || pressed "Escape" then dropped else m
  | New_folder when pressed "Enter" ->
      named caps a m (fun name -> Folder.make_folder caps (Folder.join m.dir name)) (fun name -> name ^ ": a new folder")
  | Renaming when pressed "Enter" -> (
      match selected_entry m with
      | Some e when e.name <> m.field ->
          named caps a m (fun name -> Folder.rename caps (Folder.join m.dir e.name) name) (fun name -> "now " ^ name)
      | _ -> dropped)
  | Renaming | New_folder ->
      if pressed "Escape" then dropped
      else if pressed "Backspace" then
        { m with field = String.concat "" (List.rev (match List.rev (Text.chars m.field) with [] -> [] | _ :: rest -> rest)) }
      else { m with field = m.field ^ String.concat "" (List.filter (fun c -> c >= " ") (Text.chars typed)) }

(*****************************************************************************)
(* Dragging *)
(*****************************************************************************)

let moved_enough (computer : computer) (p : press) : bool =
  abs_float (computer.mouse.mx -. p.px) +. abs_float (computer.mouse.my -. p.py) >= 6.

(* what is under the pointer that a file could be dropped in: a folder's row
 * (not the one dragged), or a folder of the path, not the one shown *)
let drop_target (computer : computer) (a : area) (m : model) (p : press) : string option =
  let x = computer.mouse.mx and y = computer.mouse.my in
  if y > a.top_y -. path_bar then
    match List.find_opt (fun (name, _, x0) -> x >= x0 && x < x0 +. width name +. 12.) (path_buttons a m) with
    | Some (_, path, _) when path <> m.dir -> Some path
    | _ -> None
  else
    match row_at a y with
    | Some i when i + m.top < Array.length m.entries && i + m.top <> p.row_pressed ->
        let e = m.entries.(i + m.top) in
        if e.is_dir then Some (Folder.join m.dir e.name) else None
    | _ -> None

let drop (caps : caps) (computer : computer) (a : area) (m : model) (p : press) : model =
  match drop_target computer a m p with
  | None -> m
  | Some dir -> (
      let e = m.entries.(p.row_pressed) in
      let m = { m with selected = p.row_pressed } in
      match tried (fun () -> Folder.move caps (Folder.join m.dir e.name) (Folder.join dir e.name)) with
      | None -> shown caps a m (next_name m) (Printf.sprintf "%s moved to %s" e.name (Filename.basename dir))
      | Some why -> shown caps a m (Some e.name) why)

let click (caps : caps) (computer : computer) (a : area) (m : model) : model =
  let x = computer.mouse.mx and y = computer.mouse.my in
  let (Time now) = computer.time in
  if y > a.top_y -. path_bar then
    match List.find_opt (fun (name, _, x0) -> x >= x0 && x < x0 +. width name +. 12.) (path_buttons a m) with
    | Some (_, path, _) -> enter caps m path
    | None -> m
  else if y > a.top_y -. path_bar -. row then
    if x >= a.day_x then sorted caps m By_day else if x >= a.size_x then sorted caps m By_size else sorted caps m By_name
  else
    match row_at a y with
    | Some i when i + m.top < Array.length m.entries -> (
        let i = i + m.top in
        match m.last_click with
        | Some (j, t) when j = i && now -. t < 0.5 -> open_selected caps { m with last_click = None; selected = i }
        | _ -> { (with_selected caps m i) with last_click = Some (i, now) })
    | _ -> m

let browse (caps : caps) (computer : computer) (m : model) : model =
  let keys = computer.keyboard.keys in
  let pressed (name : string) = Set_.mem name keys && not (Set_.mem name m.held) in
  let typed = computer.keyboard.typed in
  let a = area computer in
  let was = m.selected in
  let m =
    if pressed "ArrowDown" || pressed "down" then with_selected caps m (m.selected + 1)
    else if pressed "ArrowUp" || pressed "up" then with_selected caps m (m.selected - 1)
    else if pressed "PageDown" then with_selected caps m (m.selected + a.rows)
    else if pressed "PageUp" then with_selected caps m (m.selected - a.rows)
    else if pressed "Enter" then open_selected caps m
    else if pressed "Backspace" then enter caps m (Folder.parent ~root:m.root m.dir)
    else if typed = "b" then (
      match m.before with
      | dir :: before -> read caps { m with dir; before; said = "" } (came_from dir m.dir)
      | [] -> m)
    else if typed = "." then
      read caps { m with dots = not m.dots } (selected_name m)
    else if typed = "c" then copy_or_cut m (fun path -> Copied path) "copied"
    else if typed = "x" then copy_or_cut m (fun path -> Cut path) "cut"
    else if typed = "v" then paste caps a m
    else if typed = "d" && selected_entry m <> None then { m with asking = Some Deleting; said = "" }
    else if typed = "r" && selected_entry m <> None then
      { m with asking = Some Renaming; field = (match selected_name m with Some name -> name | None -> ""); said = "" }
    else if typed = "n" then { m with asking = Some New_folder; field = ""; said = "" }
    else if typed = "q" then CapStdlib.exit caps 0
    else m
  in
  let m = if m.selected <> was then keep_shown a m else m in
  let m =
    match m.press with
    | Some p when computer.mouse.mclick && moved_enough computer p -> drop caps computer a { m with press = None } p
    | _ when computer.mouse.mclick -> click caps computer a { m with press = None }
    | None when computer.mouse.mdown && not m.button_held -> (
        match row_at a computer.mouse.my with
        | Some i when i + m.top < Array.length m.entries && computer.mouse.my <= a.top_y -. path_bar -. row ->
            { m with press = Some { row_pressed = i + m.top; px = computer.mouse.mx; py = computer.mouse.my } }
        | _ -> m)
    | Some _ when not computer.mouse.mdown -> { m with press = None }
    | _ -> m
  in
  let last = max 0 (Array.length m.entries - a.rows) in
  let wheel = int_of_float computer.mouse.mwheel in
  let m = if wheel <> 0 then { m with top = max 0 (min last (m.top - (3 * wheel))) } else m in
  m

(* the kinds of the rows shown, a few a frame: each is a read *)
let learn_kinds (caps : caps) (a : area) (m : model) : unit =
  let left = ref 4 in
  for i = m.top to min (m.top + a.rows) (Array.length m.entries) - 1 do
    let e = m.entries.(i) in
    if !left > 0 && (not e.is_dir) && m.kinds.(i) = None then (
      decr left;
      m.kinds.(i) <- Some (fst (rule_of caps m e)))
  done

let update (caps : caps) (computer : computer) (m : model) : model =
  let a = area computer in
  let m =
    match m.asking with
    | Some q -> answer caps computer a m q
    | None -> browse caps computer m
  in
  learn_kinds caps a m;
  { m with held = computer.keyboard.keys; button_held = computer.mouse.mdown }

(*****************************************************************************)
(* The view *)
(*****************************************************************************)

let status (m : model) : string =
  match (m.asking, selected_entry m) with
  | Some Deleting, Some e ->
      Printf.sprintf "delete %s%s? y or n" e.name (if e.is_dir then " and all it holds" else "")
  | Some Renaming, _ -> "new name: " ^ m.field ^ "_"
  | Some New_folder, _ -> "new folder: " ^ m.field ^ "_"
  | _, Some e when m.said = "" && not e.is_dir -> m.kind
  | _ -> if m.said <> "" then m.said else Printf.sprintf "%d items" (Array.length m.entries)

let look_of (m : model) (i : int) (e : Folder.entry) : Icons.look =
  if e.is_dir then Icons.Folder
  else match m.kinds.(i) with Some kind -> Icons.of_kind kind | None -> Icons.Other

(* while a row is dragged: the row it would go in, under the rows' text *)
let drop_row (computer : computer) (a : area) (m : model) : shape list =
  match m.press with
  | Some p when moved_enough computer p -> (
      match (drop_target computer a m p, row_at a computer.mouse.my) with
      | Some _, Some i when computer.mouse.my <= a.top_y -. path_bar -. row ->
          [ move 0. (row_y a i) (rectangle target computer.screen.width row) ]
      | _ -> [])
  | _ -> []

(* ... and its name under the pointer *)
let dragged (computer : computer) (m : model) : shape list =
  match m.press with
  | Some p when moved_enough computer p ->
      let e = m.entries.(p.row_pressed) in
      let x = computer.mouse.mx and y = computer.mouse.my in
      [ move (x +. 16.) (y -. 2.) (Icons.draw (look_of m p.row_pressed e));
        text ink ~bold:true ~room:300. (x +. 28.) (y -. 7.) e.name ]
  | _ -> []

let view (computer : computer) (m : model) : shape list =
  let a = area computer in
  let w = computer.screen.width and h = computer.screen.height in
  let bar_at (y : float) (height : float) = move 0. y (rectangle bars w height) in
  let base (y : float) = y -. 5. in
  let header (x : float) (name : string) (order : Folder.order) =
    let mark = if m.order <> order then "" else if m.reversed then " v" else " ^" in
    text grey ~bold:true ~room:200. x (base (a.top_y -. path_bar -. (row /. 2.))) (name ^ mark)
  in
  let one_row (i : int) (e : Folder.entry) : shape list =
    let y = row_y a (i - m.top) in
    let selected = i = m.selected in
    let color = if selected then white else ink in
    let name = if e.is_dir then e.name ^ "/" else e.name in
    (if selected then [ move 0. y (rectangle chosen w row) ] else [])
    @ [ move (a.left +. 8.) y (Icons.draw (look_of m i e));
        text color ~bold:e.is_dir ~room:(a.size_x -. a.left -. 32.) (a.left +. icon_room) (base y) name ]
    @ (if e.is_dir then [] else [ text color ~bold:false ~room:95. a.size_x (base y) (Folder.size_text e.size) ])
    @ [ text color ~bold:false ~room:125. a.day_x (base y) (Folder.day_text e.mtime) ]
  in
  let rows =
    List.concat
      (List.init
         (min a.rows (Array.length m.entries - m.top))
         (fun (k : int) -> one_row (m.top + k) m.entries.(m.top + k)))
  in
  [ rectangle white w h;
    bar_at (a.top_y -. (path_bar /. 2.)) path_bar;
    bar_at ((-.h /. 2.) +. (status_bar /. 2.)) status_bar ]
  @ List.map
      (fun (name, _, x) -> text chosen ~bold:false ~room:(width name +. 1.) x (base (a.top_y -. (path_bar /. 2.))) name)
      (path_buttons a m)
  @ [ header a.left "Name" By_name; header a.size_x "Size" By_size; header a.day_x "Day" By_day ]
  @ drop_row computer a m
  @ rows
  @ [ text ink ~bold:false ~room:(a.right -. a.left) a.left (base ((-.h /. 2.) +. (status_bar /. 2.))) (status m) ]
  @ dragged computer m

(*****************************************************************************)
(* The program *)
(*****************************************************************************)

let absolute (caps : caps) (path : string) : string =
  let path = if Filename.is_relative path then Filename.concat (FS.getcwd caps ()) path else path in
  FS.cleanname path

let () =
  Cap.main (fun caps ->
      Exit.exit caps
        (Exit.catch (fun () ->
             Logging.setup caps ~name:"mini-files";
             let own = (caps :> caps) in
             let flags = Playground_platform.flags caps in
             if List.mem_assoc "help" flags then (
               Console.print caps usage;
               Exit.OK)
             else
               let dirs = List.filter (fun (name, value) -> value = "" && name <> "window") flags in
               let start = match dirs with (d, _) :: _ -> d | [] -> FS.getcwd caps () in
               let root = match List.assoc_opt "root" flags with Some r -> absolute own r | None -> "/" in
               let dir = absolute own start in
               let dir = if String.starts_with ~prefix:root dir then dir else root in
               Playground_platform.run_app caps
                 (flags @ [ ("window", "") ])
                 (Playground.game view (update own) (initial own root dir));
               Exit.OK)))
