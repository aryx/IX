(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Imap.mli *)

(*****************************************************************************)
(* The responses *)
(*****************************************************************************)

type value = Atom of string | String of string | List of value list | Nil

type response =
  | Status of string option * string * string
  | Data of value list
  | Continue of string

type token = Open | Close | Word of string | Quoted of string

(* the tokens of a text with no literal; an atom's brackets hold spaces
 * and parentheses: BODY[HEADER.FIELDS (FROM TO)] is one *)
let tokens (s : string) : token list =
  let n = String.length s in
  let rec quoted (b : Buffer.t) (j : int) : int =
    if j >= n then j
    else
      match s.[j] with
      | '\\' when j + 1 < n ->
          Buffer.add_char b s.[j + 1];
          quoted b (j + 2)
      | '"' -> j + 1
      | c ->
          Buffer.add_char b c;
          quoted b (j + 1)
  in
  let rec atom (j : int) (depth : int) : int =
    if j >= n then j
    else
      match s.[j] with
      | '[' -> atom (j + 1) (depth + 1)
      | ']' -> atom (j + 1) (max 0 (depth - 1))
      | (' ' | '(' | ')') when depth = 0 -> j
      | _ -> atom (j + 1) depth
  in
  let rec go (i : int) (acc : token list) : token list =
    if i >= n then List.rev acc
    else
      match s.[i] with
      | ' ' | '\t' | '\r' | '\n' -> go (i + 1) acc
      | '(' -> go (i + 1) (Open :: acc)
      | ')' -> go (i + 1) (Close :: acc)
      | '"' ->
          let b = Buffer.create 16 in
          let j = quoted b (i + 1) in
          go j (Quoted (Buffer.contents b) :: acc)
      | _ ->
          let j = atom i 0 in
          go j (Word (String.sub s i (j - i)) :: acc)
  in
  go 0 []

(* the values up to the list's end (a Close), and what is after it *)
let rec parse (ts : token list) : value list * token list =
  match ts with
  | [] -> ([], [])
  | Close :: rest -> ([], rest)
  | t :: rest ->
      let v, rest =
        match t with
        | Open ->
            let inner, rest = parse rest in
            (List inner, rest)
        | Quoted s -> (String s, rest)
        | Word w ->
            ((if String.uppercase_ascii w = "NIL" then Nil else Atom w), rest)
        | Close -> (Nil, rest)
      in
      let more, rest = parse rest in
      (v :: more, rest)

let values (s : string) : value list = fst (parse (tokens s))

(* a line ending in a literal's count, "... {44}": the text before it,
 * and the count ("{44+}", a client's literal that waits for no "+",
 * read the same) *)
let literal (l : string) : (string * int) option =
  let n = String.length l in
  if n > 2 && l.[n - 1] = '}' then
    match String.rindex_opt l '{' with
    | None -> None
    | Some i -> (
        let k = String.sub l (i + 1) (n - i - 2) in
        let k =
          if k <> "" && k.[String.length k - 1] = '+' then
            String.sub k 0 (String.length k - 1)
          else k
        in
        match int_of_string_opt k with
        | Some c when c >= 0 -> Some (String.sub l 0 i, c)
        | _ -> None)
  else None

(* a response's pieces: the lines' text, and the literals' bytes *)
type segment = Text of string | Literal of string

(* the first word and the rest *)
let word (s : string) : string * string =
  match String.index_opt s ' ' with
  | Some i -> (String.sub s 0 i, String.sub s (i + 1) (String.length s - i - 1))
  | None -> (s, "")

let read ~(line : unit -> string option) ~(bytes : int -> string option) :
    response option =
  let rec segments (acc : segment list) : segment list option =
    match line () with
    | None -> None
    | Some l -> (
        match literal l with
        | Some (text, n) -> (
            match bytes n with
            | Some b -> segments (Literal b :: Text text :: acc)
            | None -> None)
        | None -> Some (List.rev (Text l :: acc)))
  in
  match segments [] with
  | None -> None
  | Some segs ->
      let first, others =
        match segs with Text t :: rest -> (t, rest) | l -> ("", l)
      in
      let tag, after = word first in
      let w, text = word after in
      let status =
        others = []
        && List.mem (String.uppercase_ascii w)
             [ "OK"; "NO"; "BAD"; "BYE"; "PREAUTH" ]
      in
      if tag = "+" then Some (Continue after)
      else if status || tag <> "*" then
        Some
          (Status
             ( (if tag = "*" then None else Some tag),
               String.uppercase_ascii w,
               text ))
      else
        let ts =
          List.concat_map
            (fun s ->
              match s with Text t -> tokens t | Literal b -> [ Quoted b ])
            (Text after :: others)
        in
        Some (Data (fst (parse ts)))

let quote (s : string) : string =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter
    (fun c ->
      if c = '"' || c = '\\' then Buffer.add_char b '\\';
      Buffer.add_char b c)
    s;
  Buffer.add_char b '"';
  Buffer.contents b

let rec pairs (l : value list) : (string * value) list =
  match l with
  | Atom k :: v :: rest -> (String.uppercase_ascii k, v) :: pairs rest
  | _ :: rest -> pairs rest
  | [] -> []

let text (v : value) : string =
  match v with Atom s | String s -> s | List _ | Nil -> ""

let list (l : string list) : string =
  "("
  ^ String.concat " "
      (List.map
         (fun s -> if s = "" || String.contains s ' ' then quote s else s)
         l)
  ^ ")"

let texts (v : value) : string list =
  match v with List l -> List.map text l | _ -> []

let uid_set (uids : int list) : string =
  (* runs of consecutive UIDs as a:b *)
  let rec runs (l : int list) : (int * int) list =
    match l with
    | [] -> []
    | u :: rest -> (
        match runs rest with
        | (a, b) :: more when a = u + 1 -> (u, b) :: more
        | more -> (u, u) :: more)
  in
  String.concat ","
    (List.map
       (fun (a, b) ->
         if a = b then string_of_int a else Printf.sprintf "%d:%d" a b)
       (runs (List.sort_uniq compare uids)))

(*****************************************************************************)
(* The client *)
(*****************************************************************************)

type t = { lines : Lines.t; mutable next : int }

let read_one (t : t) : response option =
  read ~line:(fun () -> Lines.line t.lines) ~bytes:(Lines.bytes t.lines)

let ended (t : t) : string =
  match Lines.why t.lines with Some w -> w | None -> "the connection ended"

let connect (lines : Lines.t) : (t, string) result =
  let t = { lines; next = 0 } in
  match read_one t with
  | Some (Status (None, ("OK" | "PREAUTH"), _)) -> Ok t
  | Some (Status (_, w, text)) -> Error (w ^ " " ^ text)
  | Some _ -> Error "not an IMAP server's greeting"
  | None -> Error (ended t)

let command (t : t) (cmd : string) : (response list, string) result =
  t.next <- t.next + 1;
  let tag = "a" ^ string_of_int t.next in
  Lines.send_line t.lines (tag ^ " " ^ cmd);
  let rec go (acc : response list) : (response list, string) result =
    match read_one t with
    | None -> Error (ended t)
    | Some (Status (Some tg, w, text)) when tg = tag ->
        if w = "OK" then Ok (List.rev acc) else Error (w ^ " " ^ text)
    | Some r -> go (r :: acc)
  in
  go []

let login (t : t) ~(user : string) ~(password : string) : (unit, string) result
    =
  match command t ("LOGIN " ^ quote user ^ " " ^ quote password) with
  | Ok _ -> Ok ()
  | Error e -> Error e

let select (t : t) (mailbox : string) : (string, string) result =
  match command t ("SELECT " ^ quote mailbox) with
  | Error e -> Error e
  | Ok rs ->
      let validity (r : response) : string option =
        match r with
        | Status (None, "OK", text) -> (
            match values text with
            | Atom a :: _ when String.starts_with ~prefix:"[UIDVALIDITY " a ->
                let n = String.length "[UIDVALIDITY " in
                Some (String.sub a n (String.length a - n - 1))
            | _ -> None)
        | _ -> None
      in
      Ok (match List.find_map validity rs with Some v -> v | None -> "")

let mailboxes (t : t) : ((string list * string) list, string) result =
  match command t "LIST \"\" \"*\"" with
  | Error e -> Error e
  | Ok rs ->
      Ok
        (List.filter_map
           (fun r ->
             match r with
             | Data [ Atom l; attributes; _; name ]
               when String.uppercase_ascii l = "LIST" ->
                 Some (texts attributes, text name)
             | _ -> None)
           rs)

let search (t : t) (query : string) : (int list, string) result =
  match command t ("UID SEARCH " ^ query) with
  | Error e -> Error e
  | Ok rs ->
      Ok
        (List.concat_map
           (fun r ->
             match r with
             | Data (Atom s :: uids) when String.uppercase_ascii s = "SEARCH" ->
                 List.filter_map (fun v -> int_of_string_opt (text v)) uids
             | _ -> [])
           rs)

type summary = {
  uid : int;
  flags : string list;
  labels : string list;
  thread : string;
  msgid : string;
  headers : Mail.t;
}

(* each FETCH's items, its name and value pairs *)
let fetched (rs : response list) : (string * value) list list =
  List.filter_map
    (fun r ->
      match r with
      | Data [ _; Atom f; List items ] when String.uppercase_ascii f = "FETCH"
        ->
          Some (pairs items)
      | _ -> None)
    rs

(* the value of the item whose name starts so: BODY[...] *)
let item (prefix : string) (items : (string * value) list) : value =
  match List.find_opt (fun (k, _) -> String.starts_with ~prefix k) items with
  | Some (_, v) -> v
  | None -> Nil

let header_fields = "FROM TO CC SUBJECT DATE MESSAGE-ID IN-REPLY-TO REFERENCES"

let summaries (t : t) (uids : int list) : (summary list, string) result =
  if uids = [] then Ok []
  else
    match
      command t
        (Printf.sprintf
           "UID FETCH %s (UID FLAGS X-GM-LABELS X-GM-THRID X-GM-MSGID \
            BODY.PEEK[HEADER.FIELDS (%s)])"
           (uid_set uids) header_fields)
    with
    | Error e -> Error e
    | Ok rs ->
        let summary items =
          match int_of_string_opt (text (item "UID" items)) with
          | None -> None
          | Some uid ->
              Some
                {
                  uid;
                  flags = texts (item "FLAGS" items);
                  labels = texts (item "X-GM-LABELS" items);
                  thread = text (item "X-GM-THRID" items);
                  msgid = text (item "X-GM-MSGID" items);
                  headers = Mail.parse (Mail.lf (text (item "BODY[" items)));
                }
        in
        let l = List.filter_map summary (fetched rs) in
        Ok
          (List.filter_map (fun u -> List.find_opt (fun s -> s.uid = u) l) uids)

let message (t : t) (uid : int) : (string, string) result =
  match command t (Printf.sprintf "UID FETCH %d (BODY[])" uid) with
  | Error e -> Error e
  | Ok rs -> (
      match
        List.find_map
          (fun items ->
            match item "BODY[" items with String s -> Some s | _ -> None)
          (fetched rs)
      with
      | Some s -> Ok (Mail.lf s)
      | None -> Error (Printf.sprintf "no message %d" uid))

let messages (t : t) (uids : int list) : ((int * string) list, string) result =
  if uids = [] then Ok []
  else
    match
      command t
        (Printf.sprintf "UID FETCH %s (UID BODY.PEEK[])" (uid_set uids))
    with
    | Error e -> Error e
    | Ok rs ->
        Ok
          (List.filter_map
             (fun items ->
               match
                 (int_of_string_opt (text (item "UID" items)), item "BODY[" items)
               with
               | Some uid, String s -> Some (uid, Mail.lf s)
               | _ -> None)
             (fetched rs))

let store (t : t) (uids : int list) (change : string) : (unit, string) result =
  match command t (Printf.sprintf "UID STORE %s %s" (uid_set uids) change) with
  | Ok _ -> Ok ()
  | Error e -> Error e

let logout (t : t) : unit =
  (match command t "LOGOUT" with Ok _ | Error _ -> ());
  Lines.close t.lines
