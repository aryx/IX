(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Prefs.mli *)

type wallpaper = Colour of int | Picture of string

type t = { wallpaper : wallpaper; clock : string; edge : string; swap : bool; accelerated : bool; volume : int option }

let colours = [ "blue", 0x3a5f85; "green", 0x3f6f4a; "teal", 0x2f6f73; "plum", 0x6a4a7a; "grey", 0x6a7480 ]

let default = { wallpaper = Colour 0x3a5f85; clock = "24"; edge = "bottom"; swap = false; accelerated = false; volume = None }

let yes v = v = "yes"

let set (t : t) line : t =
  match String.index_opt line '=' with
  | None -> t
  | Some i ->
      let key = String.trim (String.sub line 0 i) and v = String.trim (String.sub line (i + 1) (String.length line - i - 1)) in
      let rest w = String.trim (String.sub v (String.length w) (String.length v - String.length w)) in
      let starts w = String.length v > String.length w && String.sub v 0 (String.length w) = w in
      if key = "wallpaper" && starts "colour " then
        (match int_of_string_opt ("0x" ^ rest "colour ") with Some c -> { t with wallpaper = Colour c } | None -> t)
      else if key = "wallpaper" && starts "picture " then { t with wallpaper = Picture (rest "picture ") }
      else if key = "clock" && List.mem v [ "24"; "12"; "off" ] then { t with clock = v }
      else if key = "edge" && List.mem v [ "bottom"; "top" ] then { t with edge = v }
      else if key = "swap" then { t with swap = yes v }
      else if key = "accelerated" then { t with accelerated = yes v }
      else if key = "volume" then
        (match int_of_string_opt v with Some n when n >= 0 && n <= 100 -> { t with volume = Some n } | _ -> t)
      else t

let parse text = List.fold_left set default (String.split_on_char '\n' text)

let print (t : t) =
  let b v = if v then "yes" else "no" in
  String.concat ""
    [ (match t.wallpaper with
       | Colour c -> Printf.sprintf "wallpaper=colour %06x\n" c
       | Picture p -> Printf.sprintf "wallpaper=picture %s\n" p);
      Printf.sprintf "clock=%s\nedge=%s\nswap=%s\naccelerated=%s\n" t.clock t.edge (b t.swap) (b t.accelerated);
      (match t.volume with Some v -> Printf.sprintf "volume=%d\n" v | None -> "") ]

let path home = home ^ "/lib/desktop/settings"

let clock_text (t : t) hour minute =
  if t.clock = "off" then ""
  else if t.clock = "12" then
    Printf.sprintf "%d:%02d %s" (if hour mod 12 = 0 then 12 else hour mod 12) minute (if hour < 12 then "am" else "pm")
  else Printf.sprintf "%02d:%02d" hour minute

let mouse_lines (t : t) =
  [ (if t.swap then "buttonmap 321" else "buttonmap 123"); (if t.accelerated then "accelerated" else "linear") ]
