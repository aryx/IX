(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Noweb.mli *)

open Latex_state
open Latex_input
open Latex_output

let add_to (table : (string, int list) Hashtbl.t) (key : string) (n : int) =
  let l = match Hashtbl.find_opt table key with Some l -> l | None -> [] in
  if not (List.mem n l) then Hashtbl.replace table key (l @ [ n ])

let numbers (l : int list) : string = String.concat ", " (List.map string_of_int l)

(* A chunk: its name, in which chunk the name was first defined, and
 * its lines, the chunks it names in them said the same way; then
 * where it is used. *)
let chunk (t : t) (chunk_name : string) =
  par t;
  t.chunk <- t.chunk + 1;
  let me = t.chunk in
  if not t.final then add_to t.known.defs chunk_name me;
  let lines = ref [] in
  let going = ref true in
  while !going do
    match peek t with
    | None -> going := false
    | Some _ ->
        if looking t "@\n" || looking t "@ " || (match t.input with f :: _ -> f.i + 1 = String.length f.s && f.s.[f.i] = '@' | [] -> false) then begin ignore (rest_of_line t); going := false end
        else begin
          let ends_def = looking t "<<" && (match t.input with f :: _ -> (let e = match String.index_from_opt f.s f.i '\n' with Some e -> e | None -> String.length f.s in let l = String.trim (String.sub f.s f.i (e - f.i)) in String.length l > 5 && String.sub l (String.length l - 3) 3 = ">>=") | [] -> false) in
          if ends_def then going := false else lines := rest_of_line t :: !lines
        end
  done;
  let rec trim (l : string list) : string list = match l with "" :: rest -> trim rest | l -> l in
  let lines = List.rev (trim !lines) in
  let small : Doc.style = { font = Doc.Mono; size = -2; shift = 0 } in
  let italic : Doc.style = { font = Doc.Italic; size = -2; shift = 0 } in
  let roman : Doc.style = { font = Doc.Roman; size = -2; shift = 0 } in
  let first (n : string) : string = match Hashtbl.find_opt t.known.defs n with Some (d :: _) -> " " ^ string_of_int d | _ -> "" in
  let named (n : string) : Doc.inline list =
    [ Doc.Text (italic, "\xe2\x80\xb9") ] @ with_look t { style = italic; caps = false; center = false } n @ [ Doc.Text (italic, first n ^ "\xe2\x80\xba") ] in
  let line (l : string) : Doc.inline list =
    let n = String.length l in
    let rec go (i : int) (from : int) (acc : Doc.inline list) : Doc.inline list =
      let piece (upto : int) : Doc.inline list = if upto > from then [ Doc.Text (small, String.sub l from (upto - from)) ] else [] in
      if i + 1 >= n then acc @ piece n
      else if l.[i] = '@' && l.[i + 1] = '<' && i + 2 < n && l.[i + 2] = '<' then go (i + 3) (i + 1) (acc @ piece i)
      else if l.[i] = '<' && l.[i + 1] = '<' then begin
        let rec close (j : int) : int option = if j + 1 >= n then None else if l.[j] = '>' && l.[j + 1] = '>' then Some j else close (j + 1) in
        match close (i + 2) with
        | Some j ->
            let used = String.trim (String.sub l (i + 2) (j - i - 2)) in
            if not t.final then add_to t.known.uses used me;
            go (j + 2) (j + 2) (acc @ piece i @ named used)
        | None -> go (i + 2) from acc
      end else go (i + 1) from acc in
    go 0 0 [] in
  let defs = match Hashtbl.find_opt t.known.defs chunk_name with Some l -> l | None -> [ me ] in
  let is_first = (match defs with d :: _ -> d = me | [] -> true) in
  let head = named chunk_name @ [ Doc.Text (roman, if is_first then "=" else "+=") ] in
  let uses = match Hashtbl.find_opt t.known.uses chunk_name with Some l -> l | None -> [] in
  let notes =
    (if is_first && uses <> [] then [ "used in " ^ numbers uses ] else [])
    @ (if is_first && List.length defs > 1 then [ "more in " ^ numbers (List.tl defs) ] else []) in
  let head = if notes = [] then head else head @ [ Doc.Text (roman, "   (" ^ String.concat "; " notes ^ ")") ] in
  block t (lines_as_they_are t (-2) (head :: List.map line lines))

(* \nowebindex: the chunks by name, each with the chunks that define it *)
let index (t : t) =
  par t;
  let names = List.sort compare (Hashtbl.fold (fun (k : string) (_ : int list) (acc : string list) -> k :: acc) t.known.defs []) in
  let italic : Doc.style = { font = Doc.Italic; size = -1; shift = 0 } in
  List.iter (fun (n : string) ->
    let defs = match Hashtbl.find_opt t.known.defs n with Some l -> l | None -> [] in
    let body = [ Doc.Text (italic, "\xe2\x80\xb9") ] @ with_look t { style = italic; caps = false; center = false } n @ [ Doc.Text (italic, "\xe2\x80\xba"); Doc.Text ({ italic with font = Doc.Roman }, "  " ^ numbers defs) ] in
    emit t (Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = false; body })) names
