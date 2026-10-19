(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/css/Looks.ml, its first version (docs/plans/plan_browser.md) *)

(* See Looks.mli *)

type color = int * int * int
type align = Left | Center | Right

type t = {
  size : float;
  bold : bool;
  italic : bool;
  underline : bool;
  strike : bool;
  monospace : bool;
  color : color;
  link : string option;
  pre : bool;
  align : align;
  link_color : color;
  visited_color : color;
  base : float;
  extensions : bool;
}

let root (size : float) : t =
  {
    size;
    bold = false;
    italic = false;
    underline = false;
    strike = false;
    monospace = false;
    color = (0, 0, 0);
    link = None;
    pre = false;
    align = Left;
    link_color = (0, 0, 238);
    visited_color = (85, 26, 139);
    base = size;
    extensions = false;
  }

let leading = 1.2

let font_scale (s : string) : float option =
  let scale = [| 0.625; 0.8125; 1.; 1.125; 1.5; 2.; 3. |] in
  let s = String.trim s in
  let n =
    if s <> "" && (s.[0] = '+' || s.[0] = '-') then
      Option.map (fun d -> 3 + d) (int_of_string_opt (if s.[0] = '+' then String.sub s 1 (String.length s - 1) else s))
    else int_of_string_opt s
  in
  Option.map (fun n -> scale.(max 1 (min 7 n) - 1)) n
