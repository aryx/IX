(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* A page as its boxes, printed: the file read (Html_tree), its sheets
 * cascaded and computed (the page's <style>, then the files given),
 * the boxes laid out (Box_layout) with a font of fixed width (a
 * character half its size), and each box a line: its depth, its
 * element, where it is, how large, how many lines of words it has and
 * the first line's words. What mini-ml's build of browsers/html, css
 * and engine says, compared with OCaml's (boxes.sh): no window, no
 * network.
 *
 * usage: boxes [-w width] page.html [sheet.css...] *)

let metrics (l : Looks.t) (s : string) : float = l.size *. 0.5 *. float_of_int (String.length s)

let rec show (depth : int) (b : Box_layout.box) : unit =
  let name =
    match b.element with
    | None -> "(lines)"
    | Some e -> e.name ^ (match Dom.attribute "id" e with Some id -> "#" ^ id | None -> "")
  in
  let words (l : Html_layout.line) : string = String.concat " " (List.filter (fun w -> w <> "") (List.map (fun (f : Html_layout.fragment) -> f.text) l.fragments)) in
  let first = match b.lines with l :: _ -> " \"" ^ (let w = words l in if String.length w > 40 then String.sub w 0 40 else w) ^ "\"" | [] -> "" in
  Printf.printf "%s%s %.1f %.1f %.1f %.1f%s%s\n" (String.make depth ' ') name b.x b.y b.width b.height
    (if b.lines = [] then "" else Printf.sprintf " %d" (List.length b.lines))
    first;
  List.iter (show (depth + 1)) b.children

let () =
  let read (file : string) : string = let ic = open_in_bin file in let s = really_input_string ic (in_channel_length ic) in close_in ic; s in
  let width, files =
    match List.tl (Array.to_list Sys.argv) with
    | "-w" :: w :: files -> (float_of_string w, files)
    | files -> (1000., files)
  in
  match files with
  | [] -> prerr_endline "usage: boxes [-w width] page.html [sheet.css...]"; exit 2
  | page :: sheets ->
      let root = Html_tree.of_string (Charset.decode None (read page)) in
      let media : Cascade.media = { width; height = 800. } in
      let author (text : string) : Cascade.sheet = { origin = Author; rules = Css_syntax.parse_stylesheet text } in
      let sheets = author (Css.page_sheet root) :: List.map (fun f -> author (read f)) sheets in
      let t0 = Sys.time () in
      let styles = Computed.styles media sheets root in
      let t1 = Sys.time () in
      let box = Box_layout.layout metrics Html_layout.no_picture ~viewport:(width, 800.) styles root in
      let t2 = Sys.time () in
      show 0 box;
      prerr_endline (Printf.sprintf "styles %.2f s, boxes %.2f s" (t1 -. t0) (t2 -. t1))
