(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See System.mli *)

let standard_menu = "System.Close System.Copy System.Grow Edit.Search Edit.Store"
let log_menu = "Edit.Locate Edit.Search System.Copy System.Grow System.Clear"

let w = Texts.open_writer ()
let end_line () = Texts.write_ln w; Texts.append !Oberon.log w.buf

(* the command's parameters, from the first: after its name, or at the selection for a ^ *)
let get_arg () : Texts.scanner =
  let s = Texts.open_scanner Oberon.par.text Oberon.par.pos in
  Texts.scan s;
  match s.sym, Oberon.get_selection () with
  | Char '^', Some (t, beg, _, _) -> let s = Texts.open_scanner t beg in Texts.scan s; s
  | _ -> s

(* the viewer the command was called in; whether it was in its menu *)
let in_menu () =
  match Oberon.par.vwr, Oberon.par.frame with
  | Some v, Some f -> (match v.frame.dsc with menu :: _ -> menu == f | [] -> false)
  | _ -> false

let open_viewer name menu text (x, y) =
  MenuViewers.new_ (TextFrames.new_menu name menu) (TextFrames.new_text text 0) TextFrames.menu_h x y

(*****************************************************************************)
(* The display *)
(*****************************************************************************)

let open_ () =
  let s = get_arg () in
  match s.sym with
  | Name name -> ignore (open_viewer name standard_menu (TextFrames.text name) (Oberon.allocate_system_viewer ()))
  | _ -> ()

(* (in the log's menu) the viewer's text emptied *)
let clear () =
  match Oberon.par.vwr with
  | Some { frame = { dsc = [ _; main ]; _ }; _ } when in_menu () ->
      Option.iter (fun f -> let t = TextFrames.text_of f in Texts.delete t 0 t.len (Texts.open_buf ())) (TextFrames.this main)
  | _ -> ()

(* the viewer whose menu it is called in, else the one the pointer marks *)
let close () = Option.iter Viewers.close (if in_menu () then Oberon.par.vwr else Oberon.marked_viewer ())
let close_track () = Option.iter (fun (v : Viewers.viewer) -> Viewers.close_track v.frame.x) (Oberon.marked_viewer ())

(* the last viewer closed, back *)
let recall () =
  match Viewers.recall () with
  | Some v when v.state = 0 -> Viewers.open_ v v.frame.x (v.frame.y + v.frame.h); Display.send v.frame Viewers.Restore
  | _ -> ()

let opened (v : Viewers.viewer) x y = Viewers.open_ v x y; Display.send v.frame Viewers.Restore

(* a second viewer on the same text, in the lower half of this one *)
let copy () =
  match Oberon.par.vwr with
  | Some v when v.menu_h > 0 -> opened (MenuViewers.copy v) v.frame.x (v.frame.y + (v.frame.h / 2))
  | _ -> ()

(* the viewer given its track's whole height, in a track over it; one
 * that has it, the whole display (System.Close gives the place back) *)
let grow () =
  match Oberon.par.vwr with
  | Some v when v.menu_h > 0 ->
      let f = v.frame and dw = Oberon.display_width and dh = Oberon.display_height in
      let tall = f.h >= dh - !Viewers.min_h in
      if not tall then Oberon.open_track f.x f.w else if f.w < dw then Oberon.open_track Oberon.user_track dw;
      if (not tall) || f.w < dw then opened (MenuViewers.copy v) f.x dh
  | _ -> ()

(*****************************************************************************)
(* The files *)
(*****************************************************************************)

(* a name against a pattern, whose * is any characters *)
let rec matches pat name =
  match pat, name with
  | "", "" -> true
  | "", _ -> false
  | _ when pat.[0] = '*' ->
      let rest = String.sub pat 1 (String.length pat - 1) in
      matches rest name || (name <> "" && matches pat (String.sub name 1 (String.length name - 1)))
  | _ ->
      name <> "" && pat.[0] = name.[0]
      && matches (String.sub pat 1 (String.length pat - 1)) (String.sub name 1 (String.length name - 1))

(* System.Directory *.Text (a ! after the pattern: the lengths too): in a viewer *)
let directory () =
  let word t pos =
    let r = Texts.open_reader t pos in
    let b = Buffer.create 32 in
    let rec skip () = let ch = Texts.read r in if ch = ' ' && not r.eot then skip () else ch in
    let rec take ch = if ch > ' ' && not r.eot then begin Buffer.add_char b ch; take (Texts.read r) end in
    take (skip ());
    Buffer.contents b
  in
  let pat = word Oberon.par.text Oberon.par.pos in
  let pat = match pat, Oberon.get_selection () with ("" | "^"), Some (t, beg, _, _) -> word t beg | _ -> pat in
  let lengths = pat <> "" && pat.[String.length pat - 1] = '!' in
  let pat = if lengths then String.sub pat 0 (String.length pat - 1) else pat in
  let t = TextFrames.text "" in
  ignore (open_viewer "System.Directory" standard_menu t (Oberon.allocate_system_viewer ()));
  FileDir.enumerate (fun (f : FileDir.file) ->
    if matches pat f.name then begin
      Texts.write_string w f.name;
      if lengths then Texts.write_int w f.length 8;
      Texts.write_ln w
    end);
  Texts.append t w.buf

(* the pairs old => new of the parameters, each given to [pair]; the names alone to [one] *)
let each_pair what pair =
  Texts.write_string w what; end_line ();
  let s = get_arg () in
  let rec go () =
    match s.sym with
    | Name old ->
        Texts.scan s;
        (match s.sym with
         | Char '=' ->
             Texts.scan s;
             (match s.sym with Char '>' -> Texts.scan s | _ -> ());
             (match s.sym with
              | Name new_name ->
                  Texts.write_string w (old ^ " => " ^ new_name);
                  if not (pair old new_name) then Texts.write_string w " failed";
                  end_line ();
                  Texts.scan s; go ()
              | _ -> ())
         | _ -> ())
    | _ -> ()
  in
  go ()

let copy_files () =
  each_pair "System.CopyFiles" (fun old new_name ->
    match Files.old old with
    | None -> false
    | Some f ->
        let g = Files.new_ new_name in
        let r = Files.set f 0 and wr = Files.set g 0 in
        for _i = 1 to Files.length f do Files.write wr (Files.read r) done;
        Files.register g; true)

let rename_files () = each_pair "System.RenameFiles" Files.rename

let delete_files () =
  Texts.write_string w "System.DeleteFiles"; end_line ();
  let s = get_arg () in
  let rec go () =
    match s.sym with
    | Name name ->
        Texts.write_string w (name ^ " deleting");
        if Files.old name = None then Texts.write_string w " failed" else Files.delete name;
        end_line ();
        Texts.scan s; go ()
    | _ -> ()
  in
  go ()

(*****************************************************************************)
(* The system *)
(*****************************************************************************)

let set_font () =
  let s = get_arg () in
  match s.sym with Name name -> Oberon.cur_fnt := Fonts.this name | _ -> ()

let watch () =
  Texts.write_string w "System.Watch"; Texts.write_ln w;
  let files = ref 0 and bytes = ref 0 in
  FileDir.enumerate (fun (f : FileDir.file) -> incr files; bytes := !bytes + f.length);
  Texts.write_string w "  Modules"; Texts.write_int w (List.length (Modules.modules ())) 6; Texts.write_ln w;
  Texts.write_string w "  Files"; Texts.write_int w !files 8; Texts.write_int w !bytes 8; Texts.write_string w " bytes"; Texts.write_ln w;
  Texts.write_string w "  Tasks"; Texts.write_int w (Oberon.nof_tasks ()) 8; end_line ()

let listed name lines =
  let t = TextFrames.text "" in
  ignore (open_viewer name standard_menu t (Oberon.allocate_system_viewer ()));
  List.iter (fun line -> Texts.write_string w line; Texts.write_ln w) lines;
  Texts.append t w.buf

let show_modules () = listed "System.ShowModules" (Modules.modules ())

let show_commands () =
  let s = get_arg () in
  match s.sym with
  | Name m when Modules.commands m <> [] -> listed "System.Commands" (Modules.commands m)
  | _ -> ()

let show_fonts () =
  Texts.write_string w "System.ShowFonts"; Texts.write_ln w;
  List.iter (fun name -> Texts.write w '\t'; Texts.write_string w name; Texts.write_ln w) (Fonts.names ());
  Texts.append !Oberon.log w.buf

(* the system's start: its commands said, the log and System.Tool opened *)
let () =
  List.iter (fun (name, p) -> Modules.command ("System." ^ name) p)
    [ "Open", open_; "Clear", clear; "Close", close; "CloseTrack", close_track; "Recall", recall; "Copy", copy; "Grow", grow;
      "Directory", directory; "CopyFiles", copy_files; "RenameFiles", rename_files; "DeleteFiles", delete_files;
      "SetFont", set_font; "Watch", watch; "ShowModules", show_modules; "ShowCommands", show_commands; "ShowFonts", show_fonts ];
  Oberon.open_log (TextFrames.text "");
  Texts.write_string w "mini-oberon: Project Oberon 2013, in OCaml"; end_line ();
  ignore (open_viewer "System.Log" log_menu !Oberon.log (Oberon.allocate_system_viewer ()));
  ignore (open_viewer "System.Tool" standard_menu (TextFrames.text "System.Tool") (Oberon.allocate_system_viewer ()))
