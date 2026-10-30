(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mailto.mli *)

type t = {
  to_ : string list;
  cc : string list;
  bcc : string list;
  subject : string;
  body : string;
}

let hex (c : char) : int option =
  match c with
  | '0' .. '9' -> Some (Char.code c - 48)
  | 'a' .. 'f' -> Some (Char.code c - 87)
  | 'A' .. 'F' -> Some (Char.code c - 55)
  | _ -> None

(* %XX made the byte, all else as it is ('+' a plus, not a space) *)
let unescape (s : string) : string =
  let b = Buffer.create (String.length s) in
  let n = String.length s in
  let rec go i =
    if i >= n then ()
    else if s.[i] = '%' && i + 2 < n then
      match (hex s.[i + 1], hex s.[i + 2]) with
      | Some h, Some l ->
          Buffer.add_char b (Char.chr ((h * 16) + l));
          go (i + 3)
      | _ ->
          Buffer.add_char b s.[i];
          go (i + 1)
    else begin
      Buffer.add_char b s.[i];
      go (i + 1)
    end
  in
  go 0;
  Buffer.contents b

(* "a@x,b@y" -> the addresses: split at the commas, then each decoded
 * (a %2C in a name is no separator) *)
let addresses (s : string) : string list =
  List.filter (fun a -> a <> "")
    (List.map (fun a -> String.trim (unescape a)) (String.split_on_char ',' s))

let parse (url : string) : t option =
  let n = String.length url in
  if n < 7 || String.lowercase_ascii (String.sub url 0 7) <> "mailto:" then None
  else
    let rest = String.sub url 7 (n - 7) in
    let path, query =
      match String.index_opt rest '?' with
      | Some i ->
          (String.sub rest 0 i, String.sub rest (i + 1) (String.length rest - i - 1))
      | None -> (rest, "")
    in
    let fields =
      List.filter_map
        (fun f ->
          match String.index_opt f '=' with
          | Some i ->
              Some
                ( String.lowercase_ascii (String.sub f 0 i),
                  String.sub f (i + 1) (String.length f - i - 1) )
          | None -> None)
        (String.split_on_char '&' query)
    in
    let all name =
      List.concat_map
        (fun (k, v) -> if k = name then addresses v else [])
        fields
    in
    let one name =
      match List.assoc_opt name fields with Some v -> unescape v | None -> ""
    in
    (* (the body's lines end in CR LF, as the RFC writes them: LF here) *)
    let body = String.concat "" (String.split_on_char '\r' (one "body")) in
    Some
      { to_ = addresses path @ all "to"; cc = all "cc"; bcc = all "bcc";
        subject = one "subject"; body }
