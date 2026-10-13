(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Latex_math.mli *)

open Latex_state
open Latex_input
open Latex_output
open Latex_names

(* letters in italic, the rest as it is, what is raised and lowered a
 * size smaller; the symbols the PDF's fonts have, and words for the
 * others *)
let math (t : t) (raw : string) =
  let n = String.length raw in
  let italic (style : Doc.style) : Doc.style = { style with font = Doc.Italic } in
  let rec go (style : Doc.style) (i : int) : int =
    if i >= n then n
    else
      match raw.[i] with
      | ' ' | '\n' | '\t' -> go style (i + 1)
      | '}' -> i + 1
      | '{' -> go style (go style (i + 1))
      | '^' | '_' ->
          let small : Doc.style = { style with size = style.size - 2; shift = style.shift + (if raw.[i] = '^' then 1 else -1) } in
          if i + 1 < n && raw.[i + 1] = '{' then go style (go small (i + 2))
          else if i + 1 < n && raw.[i + 1] = '\\' then go style (one small (i + 1))
          else if i + 1 < n then begin put t (Doc.Text ((if is_letter raw.[i + 1] then italic small else small), String.make 1 raw.[i + 1])); go style (i + 2) end
          else n
      | '\\' -> go style (one style i)
      | c ->
          put t (Doc.Text ((if is_letter c then italic style else style), (match c with '<' | '>' | '=' | '+' -> " " ^ String.make 1 c ^ " " | '-' -> " \xe2\x80\x93 " | ',' -> ", " | c -> String.make 1 c)));
          go style (i + 1)
  (* a command, at raw.[i]: where the reading goes on *)
  and one (style : Doc.style) (i : int) : int =
    let rec letters (j : int) : int = if j < n && is_letter raw.[j] then letters (j + 1) else j in
    let e = letters (i + 1) in
    let e = if e = i + 1 then min n (i + 2) else e in
    let w = String.sub raw (i + 1) (e - i - 1) in
    if List.mem_assoc w with_text && e < n && raw.[e] = '{' then begin
      let c = closing raw (e + 1) '{' '}' in
      let look = t.look in
      t.look <- { look with style };
      List.iter (put t) (inlines_of t ("\\" ^ w ^ "{" ^ String.sub raw (e + 1) (c - e - 1) ^ "}"));
      t.look <- look;
      min n (c + 1)
    end else begin
      (match w with
       | " " | "," | ";" | ":" -> put t (Doc.Text (style, " "))
       | "{" | "}" | "%" | "_" | "&" | "#" | "$" -> put t (Doc.Text (style, w))
       | "frac" -> ()
       | _ ->
           (match List.assoc_opt w symbols with
            | Some s -> put t (Doc.Text (style, s))
            | None -> if not (List.mem_assoc w nothing) then begin say_once t ("\\" ^ w ^ " (in mathematics)"); put t (Doc.Text (style, w)) end));
      e
    end in
  ignore (go t.look.style 0)

(* mathematics on a line of its own *)
let display (t : t) (raw : string) =
  par t;
  let saved = t.look in
  t.look <- { saved with center = true };
  math t raw;
  par t;
  t.look <- saved
