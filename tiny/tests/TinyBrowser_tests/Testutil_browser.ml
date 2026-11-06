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
      match r.part with
      | TinyBrowserLines.Run_lower -> ""
      | part ->
          let pad =
            if r.col > !at then String.make (r.col - !at) ' ' else "" in
          let text =
            match part with
            | TinyBrowserLines.Run_slice (id, 0) ->
                let pc = TinyBrowserHtml.picture_of p id in
                "[" ^ (if pc.pc_alt = "" then "picture" else pc.pc_alt) ^ ", "
                ^ string_of_int pc.pc_w ^ "x" ^ string_of_int pc.pc_h ^ "]"
            | TinyBrowserLines.Run_slice _ -> ""
            | _ -> r.text in
          at := max !at r.col + String.length text;
          pad ^ text) l.runs)
  end

let dump p width =
  String.concat ""
    (List.map (fun l -> show_line p width l ^ "\n")
       (TinyBrowserHtml.lines_between p 0 (TinyBrowserHtml.count p)))
  ^ (match TinyBrowserHtml.refresh p with
     | "" -> ""
     | u -> "(refresh: " ^ u ^ ")\n")
