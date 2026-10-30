(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Calendars.mli *)

type source = { name : string; url : string }

let sources (caps : < Cap.env ; Cap.open_in ; .. >) :
    (source list, string) result =
  match Items.secret caps "calendars" with
  | Error e -> Error e
  | Ok None -> Ok []
  | Ok (Some text) ->
      Ok
        (List.filter_map
           (fun l ->
             let l = String.trim l in
             if l = "" || l.[0] = '#' then None
             else
               match String.index_opt l ' ' with
               | Some i ->
                   Some
                     { name = String.sub l 0 i;
                       url =
                         String.trim (String.sub l i (String.length l - i)) }
               | None -> None)
           (String.split_on_char '\n' text))

let merge (items : Item.t list) (name : string) (fetched : Item.t list) :
    Item.t list * string list =
  let fetched = List.map (Mail.set "calendar" name) fetched in
  let ids = List.map Item.id fetched in
  let changed =
    List.filter
      (fun (f : Item.t) ->
        match List.find_opt (fun i -> Item.id i = Item.id f) items with
        | Some old -> Item.to_string old <> Item.to_string f
        | None -> true)
      fetched
  in
  let gone =
    List.filter_map
      (fun i ->
        if Item.field i "calendar" = name && not (List.mem (Item.id i) ids)
        then Some (Item.id i)
        else None)
      items
  in
  (changed, gone)

let fetch (caps : < Cap.network ; Cap.env ; Cap.open_in ; Cap.open_out ;
                    Cap.readdir ; .. >) (s : source) : (int * int, string) result =
  (* (its name, not its address: a secret) *)
  Logs.info (fun m -> m "calendar %s: fetching" s.name);
  match Http_client.get caps s.url with
  | Error e -> Error (s.name ^ ": " ^ e)
  | Ok r when r.status <> 200 ->
      Error (Printf.sprintf "%s: %d %s" s.name r.status r.reason)
  | Ok r ->
      let store = Items.at (Items.place caps) in
      let fetched = Events.of_ics (Zone.local caps) ~message:"" r.body in
      let changed, gone = merge (Items.all caps store) s.name fetched in
      List.iter (Items.save caps store) changed;
      List.iter (Items.remove caps store) gone;
      Logs.info (fun m ->
          m "calendar %s: %d events, %d saved, %d removed" s.name
            (List.length fetched) (List.length changed) (List.length gone));
      Ok (List.length changed, List.length gone)
