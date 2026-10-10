(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)
open Playground

(* See Part_image.mli *)

let kind = "image"

type state = {
  (* the file as it was read: what is saved *)
  bytes : string;
  (* quarter turns to the right, 0 to 3 *)
  turns : int;
  (* the file's picture, turned: what is shown. Made once, when the
   * file is read or the picture turned, so that a platform sees the
   * same value frame after frame and keeps what it made of it *)
  shown : Rgba_image.t;
}

let turned (img : Rgba_image.t) : Rgba_image.t =
  let out = Rgba_image.create ~width:img.height ~height:img.width in
  for y = 0 to img.height - 1 do
    for x = 0 to img.width - 1 do
      (* the top row becomes the right column *)
      Bytes.blit img.rgba (4 * ((y * img.width) + x)) out.rgba (4 * ((x * out.width) + (img.height - 1 - y))) 4
    done
  done;
  out

let rec turn (n : int) (img : Rgba_image.t) : Rgba_image.t = if n = 0 then img else turn (n - 1) (turned img)
let size (st : state) : float * float = (float_of_int st.shown.width, float_of_int st.shown.height)

(* at its own size, against the left of the part's box, as Part_picture *)
let draw (st : state) (b : Widget.box) ~active:(_ : bool) : shape list =
  let w, h = size st in
  [ bitmap w h st.shown |> move (Widget.left b +. (w /. 2.)) b.y ]

let command (c : string) (st : state) : state =
  match c with
  | "Rotate Right" -> { st with turns = (st.turns + 1) mod 4; shown = turned st.shown }
  | "Rotate Left" -> { st with turns = (st.turns + 3) mod 4; shown = turn 3 st.shown }
  | _ -> st

let rec part (st : state) : Component.part =
  {
    kind;
    height = (fun (_ : float) -> snd (size st));
    natural = Some (size st);
    draw = draw st;
    input = (fun (_ : computer) (_ : Widget.box) -> part st);
    menu = [ "Image"; "Rotate Left"; "Rotate Right" ];
    command = (fun (c : string) -> part (command c st));
    (* the turns, a digit, then the file *)
    save = (fun () -> string_of_int st.turns ^ st.bytes);
  }

let state (turns : int) (bytes : string) : state = { bytes; turns; shown = turn turns (Image_file.decode bytes) }
let make (bytes : string) : Component.part = part (state 0 bytes)

let load (s : string) : Component.part =
  let turns = if s = "" then -1 else Char.code s.[0] - Char.code '0' in
  if turns < 0 || turns > 3 then Component.placeholder ~kind s
  else try part (state turns (String.sub s 1 (String.length s - 1))) with Failure _ -> Component.placeholder ~kind s
