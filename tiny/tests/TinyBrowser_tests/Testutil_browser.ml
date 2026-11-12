(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Testutil_browser.mli *)

(* A picture's first row shows as [its alternative text, w x h]; its
 * other rows as nothing. *)
let show_line p width (l : Lines.line) =
  if l.rule then String.make width '-'
  else begin
    let at = ref 0 in
    String.concat "" (List.map (fun (r : Lines.run) ->
      match r.part with
      | Lines.Run_lower -> ""
      | part ->
          let pad =
            if r.col > !at then String.make (r.col - !at) ' ' else "" in
          let text =
            match part with
            | Lines.Run_slice (id, 0) ->
                let pc = Html.picture_of p id in
                "[" ^ (if pc.pc_alt = "" then "picture" else pc.pc_alt) ^ ", "
                ^ string_of_int pc.pc_w ^ "x" ^ string_of_int pc.pc_h ^ "]"
            | Lines.Run_slice _ -> ""
            | _ -> r.text in
          at := max !at r.col + String.length text;
          pad ^ text) l.runs)
  end

let dump p width =
  String.concat ""
    (List.map (fun l -> show_line p width l ^ "\n")
       (Html.lines_between p 0 (Html.count p)))
  ^ (match Html.refresh p with
     | "" -> ""
     | u -> "(refresh: " ^ u ^ ")\n")
