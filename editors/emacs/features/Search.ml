(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Search.mli *)
open Efuns

(* the regular expression that is the string itself: a \ before each
 * character Regex gives a meaning *)
let quote (s : string) : string =
  String.concat "" (List.map (fun (c : char) ->
    if String.contains "\\.[]^$*+?|()" c then "\\" ^ String.make 1 c else String.make 1 c)
    (List.init (String.length s) (String.get s)))

let regex (regexp : bool) (s : string) : Regex.t =
  match Regex.compile (if regexp then s else quote s) with
  | re -> re
  | exception Regex.Error msg -> failwith ("Regexp: " ^ msg)

(*****************************************************************************)
(* Incremental search *)
(*****************************************************************************)

let last_search : string ref = ref ""

(* what the search (or the replacement) under way found: shown in
 * reverse in the frame that asked, while its minibuffer is there *)
let found : (frame * int * int) option ref = ref None

let highlight (frame : frame) : (int * int) list =
  match !found, (Top_window.of_frame frame).top_mini with
  | Some (f, first, after), Some mini when f == frame && mini.mini_back == frame && mini.mini_cursor_back -> [ (first, after) ]
  | _ -> []

let () = Globals.editor.edt_highlights <- highlight :: Globals.editor.edt_highlights

let isearch (regexp : bool) (forward : bool) (frame : frame) : unit =
  let text = frame.frm_buffer.buf_text and origin = Frame.point frame in
  let mini = Minibuffer.create frame ((if regexp then "Regexp " else "") ^ "I-search: ") in
  found := None;
  Minibuffer.cursor_back mini;
  let forward = ref forward in
  (* where what is found starts: the next search is from there *)
  let start = ref origin in
  let typed () : string = Text.to_string mini.frm_buffer.buf_text in
  (* [search from]: forward, the first place from there; backward, the
   * last before there *)
  let search (from : int) : unit =
    if typed () = "" then Frame.goto frame origin
    else begin
      let re = regex regexp (typed ()) in
      match (if !forward then Text.search_forward text re (min from (Text.length text)) else Text.search_backward text re from) with
      | Some m ->
          start := fst m.(0);
          found := Some (frame, fst m.(0), snd m.(0));
          Frame.goto frame (if !forward then snd m.(0) else fst m.(0))
      | None -> found := None; Top_window.message mini "Failing"
    end in
  (* the same place can do for a character more *)
  let again () : unit = search (if !forward then !start else !start + 1) in
  let direction (f : bool) (_ : frame) : unit =
    forward := f;
    if typed () = "" then begin Edit.insert_string mini !last_search; again () end
    else search (if f then !start + 1 else !start) in
  let map = mini.frm_buffer.buf_map in
  List.iter (fun ((keys, action) : string * action) -> Keymap.add_binding map keys action) [
    Keymap.any_char, (fun (mini : frame) -> Edit.self_insert_command mini; again ());
    "C-s", direction true;
    "C-r", direction false;
    "DEL", (fun (mini : frame) -> Edit.delete_backspace_char mini; start := origin; again ());
    "RET", (fun (mini : frame) -> last_search := typed (); ignore (Minibuffer.kill mini));
    "C-g", (fun (mini : frame) -> Frame.goto frame origin; ignore (Minibuffer.kill mini); failwith "Quit");
  ]

let isearch_forward (frame : frame) : unit = isearch false true frame
let isearch_backward (frame : frame) : unit = isearch false false frame
let isearch_forward_regexp (frame : frame) : unit = isearch true true frame
let isearch_backward_regexp (frame : frame) : unit = isearch true false frame

(*****************************************************************************)
(* Replace *)
(*****************************************************************************)

(* from pos on, each place re is found replaced by [by]; asked first at
 * each, if [query]: the minibuffer's keys are the answers *)
let rec replace_from (frame : frame) (re : Regex.t) (by : string) (query : bool) (pos : int) (count : int) : unit =
  let text = frame.frm_buffer.buf_text in
  match (if pos > Text.length text then None else Text.search_forward text re pos) with
  | None -> Top_window.message frame (Printf.sprintf "Replaced %d occurrence%s" count (if count = 1 then "" else "s"))
  | Some m ->
      let a, b = m.(0) in
      (* (after a place that is empty, a character further) *)
      let replace (query : bool) : unit =
        ignore (Text.delete text a (b - a));
        Text.insert text a by;
        Frame.goto frame (a + String.length by);
        replace_from frame re by query (a + String.length by + (if a = b then 1 else 0)) (count + 1) in
      if not query then replace false
      else begin
        Frame.goto frame b;
        found := Some (frame, a, b);
        let mini = Minibuffer.create frame (Printf.sprintf "Replace with %s? (y, n, !, q) " by) in
        Minibuffer.cursor_back mini;
        let answer (f : unit -> unit) (mini : frame) : unit = ignore (Minibuffer.kill mini); f () in
        List.iter (fun ((keys, action) : string * action) -> Keymap.add_binding mini.frm_buffer.buf_map keys action) [
          Keymap.any_char, (fun (mini : frame) -> Top_window.message mini "y, n, ! or q");
          "y", answer (fun () -> replace true);
          "n", answer (fun () -> replace_from frame re by true (max b (a + 1)) count);
          "!", answer (fun () -> replace false);
          "q", answer (fun () -> replace_from frame re by true (Text.length text + 1) count);
        ]
      end

let replace (regexp : bool) (query : bool) (frame : frame) : unit =
  Minibuffer.read frame (if query then "Query replace: " else "Replace: ") "" Minibuffer.no_completion
    (fun (frame : frame) (what : string) ->
      if what = "" then failwith "Nothing to replace";
      Minibuffer.read frame (Printf.sprintf "Replace %s with: " what) "" Minibuffer.no_completion
        (fun (frame : frame) (by : string) -> replace_from frame (regex regexp what) by query (Frame.point frame) 0))

let replace_string (frame : frame) : unit = replace false false frame
let query_replace_string (frame : frame) : unit = replace false true frame
let replace_regexp (frame : frame) : unit = replace true false frame
let query_replace_regexp (frame : frame) : unit = replace true true frame

let () = Action.define_all [
  "isearch_forward", isearch_forward; "isearch_backward", isearch_backward;
  "isearch_forward_regexp", isearch_forward_regexp; "isearch_backward_regexp", isearch_backward_regexp;
  "replace_string", replace_string; "query_replace_string", query_replace_string;
  "replace_regexp", replace_regexp; "query_replace_regexp", query_replace_regexp;
]
