(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Letter_strokes.mli *)

let letter (color : Playground.color) ~(size : float) ~(bold : bool) ~(italic : bool) (s : string) ~(x : float) ~(baseline : float) : Playground.shape list =
  let g = Glyph_unicode.glyph s in
  let k = size /. Hershey.units_per_em in
  (* a look is a pen: thicker for bold *)
  let pen = if bold then size /. 7. else size /. 16. in
  let slant = if italic then 0.2 else 0. in
  (* a point of the glyph, in the playground: Hershey's y goes down
   * with the baseline at 9, the playground's goes up from it *)
  let at ((gx, gy) : int * int) : float * float =
    let up = float_of_int (9 - gy) *. k in
    (x +. (float_of_int (gx - g.left) *. k) +. (up *. slant), baseline +. up)
  in
  let segment ((x1, y1) : float * float) ((x2, y2) : float * float) : Playground.shape =
    let dx = x2 -. x1 and dy = y2 -. y1 in
    (* one pen-width longer than the segment, so that joints overlap
     * rather than leaving notches *)
    Playground.rectangle color (sqrt ((dx *. dx) +. (dy *. dy)) +. pen) pen
    |> Playground.rotate (atan2 dy dx *. 180. /. Float.pi)
    |> Playground.move ((x1 +. x2) /. 2.) ((y1 +. y2) /. 2.)
  in
  let rec pairs (l : (float * float) list) : Playground.shape list = match l with a :: (b :: _ as rest) -> segment a b :: pairs rest | _ -> [] in
  List.concat_map (fun (stroke : (int * int) list) -> pairs (List.map at stroke)) g.strokes

let shapes (color : Playground.color) (l : Playground.letters) : Playground.shape list =
  List.concat_map (fun ((x, s) : float * string) -> letter color ~size:l.size ~bold:l.bold ~italic:l.italic s ~x ~baseline:l.baseline) l.at
