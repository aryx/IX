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
