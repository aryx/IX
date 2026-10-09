(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Minibuffer.mli *)
open Efuns

let kill (mini : frame) : frame =
  let top = Top_window.of_frame mini in
  match top.top_mini with
  | Some m when m.mini_frame == mini ->
      top.top_mini <- None;
      top.top_active_frame <- m.mini_back;
      m.mini_back
  | _ -> mini

let create (frame : frame) (prompt : string) : frame =
  let top = Top_window.of_frame frame in
  (match top.top_mini with Some _ -> failwith "The minibuffer is in use" | None -> ());
  let buf = Ebuffer.make " *Minibuf*" None (Text.create "") in
  let mini = Frame.create frame.caps buf in
  mini.frm_has_status_line <- false;
  top.top_mini <- Some { mini_frame = mini; mini_prompt = prompt; mini_back = frame; mini_cursor_back = false };
  top.top_active_frame <- mini;
  Keymap.add_binding buf.buf_map "C-g" (fun (mini : frame) -> ignore (kill mini); failwith "Quit");
  mini

let cursor_back (mini : frame) : unit =
  match (Top_window.of_frame mini).top_mini with Some m -> m.mini_cursor_back <- true | None -> ()

(* what all of the strings start with *)
let common_prefix (l : string list) : string =
  let rec common (a : string) (b : string) (i : int) : string =
    if i < String.length a && i < String.length b && a.[i] = b.[i] then common a b (i + 1) else String.sub a 0 i in
  match l with [] -> "" | first :: rest -> List.fold_left (fun (a : string) (b : string) -> common a b 0) first rest

let complete (complete : string -> string list) (mini : frame) : unit =
  let text = mini.frm_buffer.buf_text in
  let typed = Text.to_string text in
  let answers = complete typed in
  let longer = common_prefix answers in
  if answers = [] then Top_window.message mini "No match"
  else if String.length longer > String.length typed then begin
    ignore (Text.delete text 0 (Text.length text));
    Edit.insert_string mini longer
  end
  else if List.length answers > 1 then
    (* (of a file's path, the last name) *)
    Top_window.message mini (String.concat " " (List.map (fun (a : string) ->
      if Filename.check_suffix a "/" then Filename.basename a ^ "/" else Filename.basename a) answers))

let read (frame : frame) (prompt : string) (initial : string) (completions : string -> string list)
    (action : frame -> string -> unit) : unit =
  let mini = create frame prompt in
  Edit.insert_string mini initial;
  let map = mini.frm_buffer.buf_map in
  Keymap.add_binding map "RET" (fun (mini : frame) ->
    let answer = Text.to_string mini.frm_buffer.buf_text in
    action (kill mini) answer);
  Keymap.add_binding map "TAB" (complete completions)

let among (names : string list) (typed : string) : string list =
  List.filter (fun (name : string) -> String.starts_with ~prefix:typed name) names

let no_completion (_ : string) : string list = []

let y_or_n : bool ref = ref false

let yes_or_no (frame : frame) (question : string) (action : action) : unit =
  if !y_or_n then begin
    let mini = create frame (question ^ " (y or n) ") in
    Keymap.add_binding mini.frm_buffer.buf_map "y" (fun (mini : frame) -> action (kill mini));
    Keymap.add_binding mini.frm_buffer.buf_map "n" (fun (mini : frame) -> ignore (kill mini));
    Keymap.add_binding mini.frm_buffer.buf_map Keymap.any_char (fun (mini : frame) -> Top_window.message mini "y or n")
  end
  else
    read frame (question ^ " (yes or no) ") "" (among [ "yes"; "no" ]) (fun (frame : frame) (answer : string) ->
      if answer = "yes" then action frame)
