(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Testutil_browser.mli *)

(* A picture's first row shows as [its alternative text, w x h]; its
 * other rows as nothing. *)
let show_line p width (l : TinyBrowserLines.line) =
  if l.rule then String.make width '-'
  else begin
    let at = ref 0 in
    String.concat "" (List.map (fun (r : TinyBrowserLines.run) ->
      let pad =
        if r.pic = -2 then ""
        else if r.col > !at then String.make (r.col - !at) ' '
        else "" in
      let text =
        if r.pic >= 0 && r.pic mod 256 = 0 then
          let pc = TinyBrowserPage.picture_of p (r.pic / 256) in
          "[" ^ (if pc.pc_alt = "" then "picture" else pc.pc_alt) ^ ", "
          ^ string_of_int pc.pc_w ^ "x" ^ string_of_int pc.pc_h ^ "]"
        else if r.pic = -2 then ""
        else r.text in
      if r.pic <> -2 then at := max !at r.col + String.length text;
      pad ^ text) l.runs)
  end

let dump p width =
  String.concat ""
    (List.map (fun l -> show_line p width l ^ "\n")
       (TinyBrowserPage.lines_between p 0 (TinyBrowserPage.count p)))
  ^ (match TinyBrowserPage.refresh p with
     | "" -> ""
     | u -> "(refresh: " ^ u ^ ")\n")
