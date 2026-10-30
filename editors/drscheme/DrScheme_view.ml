(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's apps/devtools/TinyDrScheme.ml, its section View: the windows (docs/plans/plan_scheme.md) *)

(* See DrScheme_view.mli *)

open Playground
open DrScheme_model
open DrScheme_draw
open DrScheme_run

let result_color = rgb 0 0 175
let output_color = rgb 150 0 150
let pink_color = rgb 255 182 193

let view_toolbar (m : model) : shape list =
  let busy = running m in
  [ box chrome 0. toolbar_y 1000. 62. ]
  @ [ caption black 60. (toolbar_y +. 30.) 17. "Untitled"; caption dark 200. (toolbar_y +. 30.) 15. "(define ...)" ]
  @ frame (rgb 160 160 150) 150. (toolbar_y +. 16.) 100. 28.
  @ button step_button [ circle (rgb 60 60 60) 5. |> move (-4.) 4.; circle (rgb 60 60 60) 5. |> move 4. (-5.) ] "Step" (not busy)
  @ button execute_button [ polygon (rgb 0 150 0) [ (-9., 10.); (-9., -10.); (10., 0.) ] ] "Execute" true
  @ button break_button [ circle (rgb 200 0 0) 10.; rectangle white 10. 3. ] "Break" busy

let view_definitions (m : model) : shape list =
  let s = Text_edit.to_string m.defs in
  let colors = colors s in
  let caret = Text_edit.caret m.defs in
  let a, b = Text_edit.range m.defs in
  let shades =
    (match m.pink with Some r -> [ (r, pink_color) ] | None -> [])
    @ (if a < b then [ ((a, b), rgb 180 200 250) ] else [])
    @ match matching s caret with Some r when m.focus = Definitions -> [ (r, rgb 225 225 225) ] | _ -> []
  in
  [ box white 0. defs_y 1000. defs_h ]
  @ text_view ~at:(text_x, defs_y +. 4.) ~rows ~top:m.top s (fun i -> if i < Array.length colors then colors.(i) else black) shades
      (if m.focus = Definitions then Some caret else None)

(* the Interactions window's content, as blocks of lines or pictures,
   from the oldest *)
type block = Lines of color * string | Picture of Scheme_image.t

let wrap (s : string) : string list =
  List.concat_map (fun l -> if l = "" then [ "" ] else List.init ((String.length l + cols - 1) / cols) (fun i -> String.sub l (i * cols) (min cols (String.length l - (i * cols))))) (String.split_on_char '\n' s)

let blocks (m : model) : block list =
  List.rev_map
    (function
      | Banner s -> Lines (black, s)
      | Echo s -> Lines (black, "> " ^ s)
      | Result (Image i) -> Picture i
      | Result v -> Lines (result_color, Scheme.print (style m) v)
      | Printed s -> Lines (output_color, s)
      | Failure s -> Lines (error_color, s)
      | Warning s -> Lines (rgb 170 120 0, s))
    m.entries

let picture_scale (i : Scheme_image.t) : float = Float.min 1. (240. /. Float.max 1. (Scheme_image.height i))

let view_interactions (m : model) : shape list =
  let height = function Lines (_, s) -> lh *. float_of_int (List.length (wrap s)) | Picture i -> (Scheme_image.height i *. picture_scale i) +. 6. in
  let prompt = "> " ^ Text_edit.to_string m.input in
  let prompt_h = if running m then 0. else lh *. float_of_int (List.length (wrap prompt)) in
  let bs = blocks m in
  let total = List.fold_left (fun acc b -> acc +. height b) prompt_h bs in
  (* the bottom kept in view, as the window scrolls with its output *)
  let y0 = inter_y +. 4. -. Float.max 0. (total -. (inter_h -. 8.)) in
  (* only what fits whole: no clipping in the Playground *)
  let visible y h = y >= inter_y && y +. h <= inter_y +. inter_h in
  let shapes, y =
    List.fold_left
      (fun (acc, y) b ->
        let h = height b in
        let s =
          if not (visible y h) then []
          else
            match b with
            | Lines (c, s) -> List.concat (List.mapi (fun i l -> let ly = y +. (float_of_int i *. lh) in if visible ly lh then label c text_x ly l else []) (wrap s))
            | Picture i ->
                let k = picture_scale i in
                [ Bigbang.to_shape (picture i) |> scale k |> at (text_x +. (Scheme_image.width i *. k /. 2.)) (y +. 3. +. (Scheme_image.height i *. k /. 2.)) ]
        in
        (s @ acc, y +. h))
      ([], y0) bs
  in
  let prompt_shapes =
    if running m then []
    else
      let input = Text_edit.to_string m.input in
      let caret = Text_edit.caret m.input in
      List.concat
        (List.mapi
           (fun i l ->
             let ly = y +. (float_of_int i *. lh) in
             if not (visible ly lh) then [] else label black text_x ly l)
           (wrap prompt))
      @
      if m.focus = Interactions then
        let line, col = place input caret in
        let col = if line = 0 then col + 2 else col in
        [ box black (text_x +. (float_of_int col *. cw) -. 1.) (y +. (float_of_int line *. lh) +. 1.) 2. (lh -. 2.) ]
      else []
  in
  (* the window's white, its content clipped by the chrome drawn over it *)
  [ box white 0. inter_y 1000. inter_h ] @ List.rev shapes @ prompt_shapes

let view_status (m : model) : shape list =
  let s = Text_edit.to_string m.defs in
  let line, col = place s (Text_edit.caret m.defs) in
  let lang = match m.level with Beginning -> "Beginning Student" | Standard -> "Standard (R5RS)" in
  [ box chrome 0. status_y 1000. 40.; caption black 190. (status_y +. 20.) 15. ("Language: " ^ lang ^ "  (click)") ]
  @ [ caption dark 820. (status_y +. 20.) 15. (Printf.sprintf "%d:%d" (line + 1) col) ]
  @
  if running m then
    (* the running indicator, turning *)
    let a = float_of_int (m.frames * 12) in
    [ caption (rgb 0 120 0) 690. (status_y +. 20.) 15. "running"; rectangle (rgb 0 150 0) 16. 4. |> rotate a |> at 960. (status_y +. 20.) ]
  else []

let view (_computer : computer) (m : model) : shape list =
  [ box chrome 0. 0. 1000. 1000. ]
  @ view_definitions m
  (* the divider, between the two windows *)
  @ [ box chrome 0. (defs_y +. defs_h) 1000. (inter_y -. defs_y -. defs_h); box (rgb 200 200 190) 470. (defs_y +. defs_h +. 2.) 60. 3. ]
  @ view_interactions m
  (* the chrome over the texts' overflow *)
  @ [ box title_blue 0. 0. 1000. title_h; caption white 500. 17. 17. "Untitled - DrScheme" ]
  @ view_toolbar m
  @ view_status m
  @ (match m.status with World w -> view_world w | Idle | Busy _ -> [])
  @ match m.stepper with Some s -> view_stepper s | None -> []
