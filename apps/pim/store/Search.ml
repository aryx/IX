(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Search.mli *)

type term =
  | Word of string
  | Field of string * string (* name, value *)
  | Is of string
  | Label of string
  | Before of Civil.date
  | After of Civil.date

(* each term, and whether it is negated *)
type t = (bool * term) list

let lower = String.lowercase_ascii

let contains (s : string) (word : string) : bool =
  let s = lower s and w = lower word in
  let n = String.length s and k = String.length w in
  let rec at i = i + k <= n && (String.sub s i k = w || at (i + 1)) in
  at 0

let date (s : string) : Civil.date option =
  match
    String.split_on_char '-'
      (String.map (fun c -> if c = '/' then '-' else c) s)
  with
  | [ y; m; d ] -> (
      match (int_of_string_opt y, int_of_string_opt m, int_of_string_opt d) with
      | Some year, Some month, Some day ->
          let d : Civil.date = { year; month; day } in
          if Civil.is_valid d then Some d else None
      | _ -> None)
  | _ -> None

(* the words of a query, a quoted phrase one *)
let tokens (q : string) : string list =
  let n = String.length q in
  let rec go i (cur : Buffer.t) (quoted : bool) (acc : string list) =
    let flush () =
      if Buffer.length cur = 0 then acc else Buffer.contents cur :: acc
    in
    if i >= n then List.rev (flush ())
    else
      match q.[i] with
      | '"' -> go (i + 1) cur (not quoted) acc
      | (' ' | '\t') when not quoted ->
          let acc = flush () in
          go (i + 1) (Buffer.create 8) false acc
      | c ->
          Buffer.add_char cur c;
          go (i + 1) cur quoted acc
  in
  go 0 (Buffer.create 8) false []

let term (tok : string) : term =
  match String.index_opt tok ':' with
  | None -> Word tok
  | Some i -> (
      let name = lower (String.sub tok 0 i) in
      let v = String.sub tok (i + 1) (String.length tok - i - 1) in
      match (name, date v) with
      | "is", _ -> Is (lower v)
      | "label", _ -> Label v
      | "before", Some d -> Before d
      | "after", Some d -> After d
      | _ -> Field (name, v))

let parse (q : string) : t =
  List.map
    (fun tok ->
      if String.length tok > 1 && tok.[0] = '-' then
        (true, term (String.sub tok 1 (String.length tok - 1)))
      else (false, term tok))
    (tokens q)

let day (item : Item.t) : Civil.date option =
  let field = Item.field item in
  let prefix s = if String.length s >= 10 then String.sub s 0 10 else s in
  match (date (prefix (field "due")), date (prefix (field "when"))) with
  | Some d, _ | None, Some d -> Some d
  | None, None -> (
      match Mail.date (field "date") with Some d -> Some d.day | None -> None)

let holds (item : Item.t) (t : term) : bool =
  let values =
    List.map (fun (f : Mail.field) -> Mail.unfold f.raw) item.fields
  in
  let word w = List.exists (fun v -> contains v w) (item.body :: values) in
  let compare_day f =
    match day item with Some d -> f (Civil.days_from_civil d) | None -> false
  in
  match t with
  | Word w -> word w
  | Field (name, v) ->
      if Mail.get item name <> None then contains (Item.field item name) v
      else word (name ^ ":" ^ v)
  | Is "unread" ->
      Item.has_stamp item "message"
      && not (contains (Item.field item "flags") "\\seen")
  | Is "read" ->
      Item.has_stamp item "message"
      && contains (Item.field item "flags") "\\seen"
  | Is stamp -> List.mem stamp (List.map lower (Item.stamps item))
  | Label l -> contains (Item.field item "labels") l
  | Before d -> compare_day (fun x -> x < Civil.days_from_civil d)
  | After d -> compare_day (fun x -> x >= Civil.days_from_civil d)

let matches (q : t) (item : Item.t) : bool =
  List.for_all (fun (negated, t) -> holds item t <> negated) q

let search (q : string) (items : Item.t list) : Item.t list =
  let q = parse q in
  List.filter (matches q) items
