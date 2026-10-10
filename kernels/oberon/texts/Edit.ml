(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Edit.mli *)

let w = Texts.open_writer ()
let max_len = 32

(* a viewer's text frame: its main frame's, if it is one *)
let text_frame (v : Viewers.viewer) = match v.frame.dsc with [ _; main ] -> TextFrames.this main | _ -> None
let menu_text (v : Viewers.viewer) = match v.frame.dsc with menu :: _ -> Option.map TextFrames.text_of (TextFrames.this menu) | [] -> None
let in_menu () =
  match Oberon.par.vwr, Oberon.par.frame with
  | Some v, Some f -> (match v.frame.dsc with menu :: _ -> menu == f | [] -> false)
  | _ -> false

(* Edit.Open name, or the name selected (a ^, or nothing on the line) *)
let open_ () =
  let s = Texts.open_scanner Oberon.par.text Oberon.par.pos in
  Texts.scan s;
  let s =
    match s.sym, Oberon.get_selection () with
    | Char '^', Some (t, beg, _, _) -> let s = Texts.open_scanner t beg in Texts.scan s; s
    | _, Some (t, beg, _, _) when s.line <> 0 -> let s = Texts.open_scanner t beg in Texts.scan s; s
    | _ -> s
  in
  match s.sym with
  | Name name ->
      let x, y = Oberon.allocate_user_viewer () in
      ignore (MenuViewers.new_ (TextFrames.new_menu name System.standard_menu) (TextFrames.new_text (TextFrames.text name) 0)
                TextFrames.menu_h x y)
  | _ -> ()

(* (in a viewer's menu) its text stored under the menu's first word,
 * the file that had the name kept as name.Bak; elsewhere, the marked
 * viewer's, under the name given *)
let store () =
  Texts.write_string w "Edit.Store ";
  let v, s =
    if in_menu () then Oberon.par.vwr, Option.map (fun t -> Texts.open_scanner t 0) (Option.bind Oberon.par.vwr menu_text)
    else Oberon.marked_viewer (), Some (Texts.open_scanner Oberon.par.text Oberon.par.pos)
  in
  match v, s with
  | Some v, Some s -> (
      Texts.scan s;
      match s.sym, text_frame v with
      | Name name, Some f ->
          let t = TextFrames.text_of f in
          Texts.write_string w name; Texts.write_int w t.len 8; Texts.write_ln w;
          Texts.append !Oberon.log w.buf;
          ignore (Files.rename name (name ^ ".Bak"));
          Texts.close t name
      | _ -> ())
  | _ -> ()

(* the selection given the font named *)
let change_font () =
  match Oberon.get_selection () with
  | Some (t, beg, end_, _) ->
      let s = Texts.open_scanner Oberon.par.text Oberon.par.pos in
      Texts.scan s;
      (match s.sym with Name name -> Texts.change_looks t beg end_ (Fonts.this name) | _ -> ())
  | None -> ()

(* the selection given the looks at the focus viewer's caret *)
let copy_looks () =
  match Oberon.get_selection (), Option.bind !Oberon.focus_viewer text_frame with
  | Some (t, beg, end_, _), Some f ->
      Option.iter (fun pos -> Texts.change_looks t beg end_ (Texts.attributes (TextFrames.text_of f) pos)) (TextFrames.caret f)
  | _ -> ()

(* the frame showing a position, the caret there *)
let go_to (v : Viewers.viewer) f back pos =
  TextFrames.remove_selection f; TextFrames.remove_caret f;
  Oberon.remove_marks v.frame.x v.frame.y v.frame.w v.frame.h;
  TextFrames.show f (max 0 (pos - back));
  Oberon.pass_focus (Some v);
  TextFrames.set_caret f pos

(* The selection, when it is newer than the last search's, is what is
 * searched (its first 32 characters); it is looked for from the caret
 * on, in the viewer whose menu has the command, else the focus viewer;
 * found, the caret is put after it. (Oberon's is Boyer and Moore's
 * search; here each place is tried.) *)
let pattern = ref ""
let pattern_time = ref (-1)

let search () =
  let v = if in_menu () then Oberon.par.vwr else !Oberon.focus_viewer in
  match v, Option.bind v text_frame with
  | Some v, Some f ->
      (match Oberon.get_selection () with
       | Some (t, beg, end_, time) when time > !pattern_time ->
           let r = Texts.open_reader t beg in
           pattern := String.init (min max_len (end_ - beg)) (fun _ -> Texts.read r);
           pattern_time := time
       | _ -> ());
      let t = TextFrames.text_of f and m = String.length !pattern in
      let at pos =
        let r = Texts.open_reader t pos in
        let rec same i = i = m || (Texts.read r = !pattern.[i] && same (i + 1)) in
        same 0
      in
      let rec find pos = if pos + m > t.len then None else if at pos then Some (pos + m) else find (pos + 1) in
      if m > 0 then Option.iter (go_to v f 300) (find (match TextFrames.caret f with Some pos -> pos | None -> 0))
  | _ -> ()

(* the first number in the selection is a position in the focus viewer's text: shown *)
let locate () =
  match !Oberon.focus_viewer, Oberon.get_selection () with
  | Some v, Some (t, beg, _, _) ->
      let s = Texts.open_scanner t beg in
      let rec number () = Texts.scan s; match s.sym with Int n -> Some n | Name _ -> number () | _ -> None in
      (match text_frame v, number () with Some f, Some n -> go_to v f 200 n | _ -> ())
  | _ -> ()

(* what was last deleted, back at the caret *)
let recall () =
  match Option.bind !Oberon.focus_viewer text_frame with
  | Some f ->
      Option.iter (fun pos ->
        let b = TextFrames.recall () in
        let n = b.blen in
        Texts.insert (TextFrames.text_of f) pos b;
        TextFrames.set_caret f (pos + n)) (TextFrames.caret f)
  | None -> ()

let () =
  List.iter (fun (name, p) -> Modules.command ("Edit." ^ name) p)
    [ "Open", open_; "Store", store; "ChangeFont", change_font; "CopyLooks", copy_looks; "Search", search; "Locate", locate; "Recall", recall ]
