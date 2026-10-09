(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Config_pad.mli *)

let rgb ((r, g, b) : int * int * int) : Vt.attrs = { Vt.plain with fg = Rgb (r, g, b) }

(* codemap's colors (the playground's Highlight_code.rgb), their X11 names *)
let wheat = (245, 222, 179)
let dark_slate_gray = (47, 79, 79)

let color (category : Highlight_code.category) : Vt.attrs =
  rgb (match category with
    | Comment -> (190, 190, 190) (* gray *)
    | Comment_section -> (255, 127, 80) (* coral *)
    | Keyword -> (255, 165, 0) (* orange *)
    | Keyword_control -> (255, 140, 0) (* DarkOrange *)
    | Keyword_module -> (210, 105, 30) (* chocolate *)
    | Def_function -> (238, 201, 0) (* gold2 *)
    | Def_value -> (255, 215, 0) (* gold *)
    | Def_type -> (154, 205, 50) (* YellowGreen *)
    | Def_module -> (255, 127, 36) (* chocolate1 *)
    | Parameter -> (92, 172, 238) (* SteelBlue2 *)
    | Local -> (135, 206, 255) (* SkyBlue1 *)
    | Global -> (250, 128, 114) (* salmon *)
    | Module -> (210, 105, 30) (* chocolate *)
    | Constructor -> (255, 181, 197) (* pink1 *)
    | Type -> (127, 255, 0) (* chartreuse *)
    | Type_var -> (50, 205, 50) (* LimeGreen *)
    | Label -> (100, 149, 237) (* CornflowerBlue *)
    | Capability -> (255, 64, 64) (* red: authority *)
    | Number -> (205, 205, 0) (* yellow3 *)
    | String -> (60, 179, 113) (* MediumSeaGreen *)
    | Operator -> (0, 154, 205) (* DeepSkyBlue3 *)
    | Punctuation -> (0, 205, 205) (* cyan3 *)
    | Attribute -> (238, 118, 0) (* DarkOrange2 *)
    | Normal -> wheat
    | Error -> (255, 99, 71) (* tomato *)
    | Field -> (159, 121, 238)) (* MediumPurple2 *)

(* dircolors.el's: the ends of a file's name, and its color; the first
 * that fits *)
let dircolors : (string list * (int * int * int)) list = [
  [ ".txt"; ".man"; ".md" ], (72, 209, 204); (* MediumTurquoise: a document *)
  [ ".doc" ], (64, 224, 208); (* turquoise *)
  [ ".tex"; ".texi" ], (102, 205, 170); (* medium aquamarine *)
  [ ".nw" ], (255, 215, 0); (* gold: a literate program *)
  [ ".org" ], (32, 178, 170); (* light sea green *)
  [ ".htm"; ".html" ], (221, 160, 221); (* Plum *)
  [ ".rpm"; ".deb"; ".dmg" ], (205, 92, 92); (* IndianRed: a package *)
  [ ".tar"; ".tgz"; ".tar.gz"; ".tar.bz2"; ".zip"; ".rar" ], (255, 69, 0); (* OrangeRed *)
  [ ".bak"; ".BAK"; ".save"; "~" ], (255, 0, 255); (* Magenta: a backup *)
  [ ".mp3"; ".au"; ".wav" ], (173, 216, 230); (* LightBlue: a sound *)
  [ ".jpg"; ".gif"; ".bmp"; ".xbm"; ".tif"; ".xpm"; ".jpeg"; ".png"; ".ppm" ], (250, 128, 114); (* Salmon: a picture *)
  [ ".avi"; ".mpg"; ".mpeg"; ".mov"; ".mp4" ], (238, 99, 99); (* IndianRed2: a movie *)
  [ ".ps"; ".pdf"; ".eps" ], (147, 112, 219); (* medium purple *)
  [ ".exe"; ".com"; ".bat" ], (50, 205, 50); (* LimeGreen *)
  [ "akefile"; "mkfile"; "dune" ], (240, 230, 140); (* khaki: what builds *)
  [ ".ml"; ".hs"; ".scm"; ".pl"; ".st" ], (255, 255, 0); (* yellow: a language *)
  [ ".php"; ".py"; ".js"; ".p"; ".pas"; ".c"; ".cpp"; ".cc"; ".sh" ], (205, 205, 0); (* yellow3 *)
  [ ".el"; ".emacs" ], (173, 255, 47); (* GreenYellow *)
  [ ".mli"; ".h"; ".hpp" ], (218, 165, 32); (* Goldenrod: an interface *)
  [ ".mly"; ".mll"; ".l"; ".y" ], (255, 127, 80); (* Coral *)
  [ ".o"; ".cmo"; ".cmi"; ".cmx"; ".cma"; ".cmxa"; ".annot"; ".cmt"; ".cmti"; ".a"; ".5"; ".7" ], (105, 105, 105); (* DimGray: an object *)
  [ ".asm"; ".s"; ".S" ], (210, 180, 140); (* Tan *)
  [ ".gz" ], (160, 82, 45); (* Sienna: compressed *)
]

let dircolor (name : string) : Vt.attrs =
  if Filename.check_suffix name "/" || name = ".." then rgb (100, 149, 237) (* CornflowerBlue *)
  else
    match List.find_opt (fun ((ends, _) : string list * (int * int * int)) ->
      List.exists (fun (e : string) -> Filename.check_suffix name e) ends) dircolors with
    | Some (_, c) -> rgb c
    | None -> Vt.plain

(* his GTD's file (config/pad.ml's gtd) *)
let gtd (frame : Efuns.frame) : unit = Multi_buffers.open_file frame "/home/pad/GTD/GTD-daily.org"

let config () : unit =
  Globals.editor.edt_plain <- { (rgb wheat) with bg = (rgb dark_slate_gray).fg };
  Highlight.attrs := color;
  Dired.color := dircolor;
  Minibuffer.y_or_n := true;
  Multi_buffers.ignored_extensions := [ ".cmo"; ".cmi"; ".cma"; ".annot"; ".cmx"; ".cmt"; ".cmti"; ".o" ];
  Action.define "gtd" gtd;
  List.iter (fun ((keys, action) : string * Efuns.action) -> Keymap.add_global_key keys action) [
    "M-g", Transform.goto_line;
    "M-C-l", Multi_buffers.switch_to_other_buffer;
    "M-<down>", (fun (frame : Efuns.frame) -> Move.forward_line frame; Scroll.scroll_up frame);
    "M-<up>", (fun (frame : Efuns.frame) -> Move.backward_line frame; Scroll.scroll_down frame);
  ]
