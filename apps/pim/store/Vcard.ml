(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Vcard.mli *)

type card = {
  name : string;
  emails : string list;
  phones : string list;
  birthday : string;
  org : string;
  note : string;
}

(* "item1.EMAIL" -> "EMAIL": Apple's and Google's groups *)
let ungrouped (n : string) : string =
  match String.rindex_opt n '.' with
  | Some i -> String.sub n (i + 1) (String.length n - i - 1)
  | None -> n

(* "19800315", "1980-03-15", "--0315", "--03-15" -> "1980-03-15",
 * "--03-15" *)
let day (v : string) : string =
  let d = String.concat "" (String.split_on_char '-' (String.trim v)) in
  let year_less = String.length v > 1 && String.sub v 0 2 = "--" in
  match String.length d with
  | 8 when not year_less ->
      Printf.sprintf "%s-%s-%s" (String.sub d 0 4) (String.sub d 4 2)
        (String.sub d 6 2)
  | 4 when year_less ->
      Printf.sprintf "--%s-%s" (String.sub d 0 2) (String.sub d 2 2)
  | _ -> ""

let card_of (props : (string * string) list) : card =
  let all n =
    List.filter_map (fun (k, v) -> if k = n then Some v else None) props
  in
  let one n = match all n with v :: _ -> v | [] -> "" in
  let name =
    match one "FN" with
    | "" -> (
        (* N: family; given; ... *)
        match String.split_on_char ';' (one "N") with
        | family :: given :: _ -> String.trim (given ^ " " ^ family)
        | [ family ] -> family
        | [] -> "")
    | fn -> fn
  in
  { name;
    emails =
      List.map (fun e -> String.lowercase_ascii (String.trim e)) (all "EMAIL");
    phones = List.map String.trim (all "TEL");
    birthday = day (one "BDAY");
    org =
      (match String.split_on_char ';' (one "ORG") with o :: _ -> o | [] -> "");
    note = one "NOTE" }

let of_string (s : string) : card list =
  let rec go lines current acc =
    match lines with
    | [] -> List.rev acc
    | (n, _, v) :: rest -> (
        match (ungrouped n, current) with
        | "BEGIN", _ when String.uppercase_ascii v = "VCARD" ->
            go rest (Some []) acc
        | "END", Some props when String.uppercase_ascii v = "VCARD" ->
            go rest None (card_of (List.rev props) :: acc)
        | n, Some props -> go rest (Some ((n, Ics.unescape v) :: props)) acc
        | _, None -> go rest None acc)
  in
  go (List.filter_map Ics.content_line (Ics.unfold s)) None []

let to_item (c : card) : Item.t option =
  match c.emails with
  | [] -> None
  | first :: _ ->
      let opt n v = if v = "" then [] else [ (n, v) ] in
      Some
        (Item.make
           ~id:(People.id { display = c.name; mailbox = first })
           ~stamps:[ "contact" ]
           (List.concat
              [ [ ("name", if c.name = "" then first else c.name) ];
                List.map (fun e -> ("email", e)) c.emails;
                List.map (fun p -> ("phone", p)) c.phones;
                opt "birthday" c.birthday; opt "org" c.org ])
           c.note)
