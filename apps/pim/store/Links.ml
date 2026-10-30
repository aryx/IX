(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Links.mli *)

(* the words of an item's fields but its id: and stamp:, each with its
 * field's name *)
let named (item : Item.t) : (string * string) list =
  List.concat_map
    (fun (f : Mail.field) ->
      let name = String.lowercase_ascii f.name in
      if name = "id" || name = "stamp" then []
      else
        let words =
          String.split_on_char ' '
            (String.map (fun c -> if c = ',' || c = '\t' then ' ' else c)
               (Mail.unfold f.raw))
        in
        List.filter_map
          (fun w -> if w = "" then None else Some (name, w))
          words)
    item.fields

(* the ids in [[ ]] of a text, a note's links (plan_pim.md, stage 7) *)
let bracketed (text : string) : string list =
  let n = String.length text in
  let rec from i acc =
    if i + 1 >= n then List.rev acc
    else if text.[i] = '[' && text.[i + 1] = '[' then
      let rec close j =
        if j + 1 >= n then None
        else if text.[j] = ']' && text.[j + 1] = ']' then Some j
        else if text.[j] = '\n' then None
        else close (j + 1)
      in
      match close (i + 2) with
      | Some j ->
          from (j + 2) (String.trim (String.sub text (i + 2) (j - i - 2)) :: acc)
      | None -> from (i + 2) acc
    else from (i + 1) acc
  in
  from 0 []

(* what an item names: its fields' words, and its text's [[ ]], named
 * "text" *)
let named (item : Item.t) : (string * string) list =
  named item @ List.map (fun id -> ("text", id)) (bracketed item.body)

let links (items : Item.t list) (item : Item.t) : (string * Item.t) list =
  let by_id = Hashtbl.create 64 in
  List.iter (fun i -> Hashtbl.replace by_id (Item.id i) i) items;
  List.filter_map
    (fun (name, w) ->
      match Hashtbl.find_opt by_id w with
      | Some i when Item.id i <> Item.id item -> Some (name, i)
      | _ -> None)
    (named item)

let backlinks (items : Item.t list) (item : Item.t) : (string * Item.t) list =
  let id = Item.id item in
  List.filter_map
    (fun i ->
      if Item.id i = id then None
      else
        match List.find_opt (fun (_, w) -> w = id) (named i) with
        | Some (name, _) -> Some (name, i)
        | None -> None)
    items
