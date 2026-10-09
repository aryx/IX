(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Text.mli. The design is efuns' Text (Fabrice Le Fessant, INRIA,
 * 1998): a gap buffer, points, a history; written anew. *)

type point = { mutable pos : int }

(* what was done, to do the inverse: [Inserted (pos, len)],
 * [Deleted (pos, the bytes)] *)
type change = Inserted of int * int | Deleted of int * string | Boundary

type t = {
  (* the text is bytes' [0, gap) then [gap + gap_len, its end) *)
  mutable bytes : Bytes.t;
  mutable gap : int;
  mutable gap_len : int;
  mutable points : point list;
  (* the last change first *)
  mutable undos : change list;
  mutable version : int;
}

let create (s : string) : t =
  { bytes = Bytes.of_string s; gap = String.length s; gap_len = 0; points = []; undos = []; version = 0 }

let length (t : t) : int = Bytes.length t.bytes - t.gap_len
let version (t : t) : int = t.version

let get (t : t) (pos : int) : char =
  if pos < 0 || pos >= length t then invalid_arg "Text.get";
  Bytes.get t.bytes (if pos < t.gap then pos else pos + t.gap_len)

let sub (t : t) (pos : int) (len : int) : string =
  if pos < 0 || len < 0 || pos + len > length t then invalid_arg "Text.sub";
  let b = Bytes.create len in
  (* what is before the gap, then what is after *)
  let before = max 0 (min len (t.gap - pos)) in
  Bytes.blit t.bytes pos b 0 before;
  Bytes.blit t.bytes (pos + before + t.gap_len) b before (len - before);
  Bytes.to_string b

let to_string (t : t) : string = sub t 0 (length t)

(*****************************************************************************)
(* Changes *)
(*****************************************************************************)

(* the bytes between the gap and pos go to its other side *)
let move_gap (t : t) (pos : int) : unit =
  if pos < t.gap then Bytes.blit t.bytes pos t.bytes (pos + t.gap_len) (t.gap - pos)
  else Bytes.blit t.bytes (t.gap + t.gap_len) t.bytes t.gap (pos - t.gap);
  t.gap <- pos

(* a gap of n bytes at least: the text copied to a larger place, with
 * room for what is typed next (a quarter more, so that a long text
 * typed in is copied a number of times that is its logarithm) *)
let room (t : t) (n : int) : unit =
  if t.gap_len < n then begin
    let gap_len = n + max 64 (length t / 4) in
    let b = Bytes.create (length t + gap_len) in
    let after = t.gap + t.gap_len in
    Bytes.blit t.bytes 0 b 0 t.gap;
    Bytes.blit t.bytes after b (t.gap + gap_len) (Bytes.length t.bytes - after);
    t.bytes <- b;
    t.gap_len <- gap_len
  end

(* the two changes, not recorded: undo's own *)
let insert_ (t : t) (pos : int) (s : string) : unit =
  if pos < 0 || pos > length t then invalid_arg "Text.insert";
  let n = String.length s in
  move_gap t pos;
  room t n;
  Bytes.blit_string s 0 t.bytes t.gap n;
  t.gap <- t.gap + n;
  t.gap_len <- t.gap_len - n;
  List.iter (fun (p : point) -> if p.pos > pos then p.pos <- p.pos + n) t.points;
  t.version <- t.version + 1

let delete_ (t : t) (pos : int) (len : int) : string =
  let s = sub t pos len in
  move_gap t pos;
  t.gap_len <- t.gap_len + len;
  List.iter (fun (p : point) -> if p.pos > pos then p.pos <- max pos (p.pos - len)) t.points;
  t.version <- t.version + 1;
  s

let insert (t : t) (pos : int) (s : string) : unit =
  insert_ t pos s;
  if s <> "" then t.undos <- Inserted (pos, String.length s) :: t.undos

let delete (t : t) (pos : int) (len : int) : string =
  let s = delete_ t pos len in
  if len > 0 then t.undos <- Deleted (pos, s) :: t.undos;
  s

(*****************************************************************************)
(* Points *)
(*****************************************************************************)

let get_position (p : point) : int = p.pos
let set_position (t : t) (p : point) (pos : int) : unit = p.pos <- max 0 (min pos (length t))

let new_point (t : t) (pos : int) : point =
  let p = { pos = 0 } in
  set_position t p pos;
  t.points <- p :: t.points;
  p

let remove_point (t : t) (p : point) : unit = t.points <- List.filter (fun (q : point) -> q != p) t.points

(*****************************************************************************)
(* Lines *)
(*****************************************************************************)

let rec bol (t : t) (pos : int) : int = if pos > 0 && get t (pos - 1) <> '\n' then bol t (pos - 1) else pos
let rec eol (t : t) (pos : int) : int = if pos < length t && get t pos <> '\n' then eol t (pos + 1) else pos

let rec forward_line (t : t) (pos : int) (n : int) : int =
  let start = bol t pos in
  if n > 0 then
    let e = eol t pos in
    if e = length t then start else forward_line t (e + 1) (n - 1)
  else if n < 0 && start > 0 then forward_line t (start - 1) (n + 1)
  else start

let newlines (t : t) (from : int) (upto : int) : int =
  let n = ref 0 in
  for i = from to upto - 1 do if get t i = '\n' then incr n done;
  !n

let line (t : t) (pos : int) : int = newlines t 0 pos

(*****************************************************************************)
(* Undo *)
(*****************************************************************************)

let boundary (t : t) : unit =
  match t.undos with
  | [] | Boundary :: _ -> ()
  | _ -> t.undos <- Boundary :: t.undos

let undo (t : t) : int option =
  (* at: where the last change undone left off; the boundaries that
   * are met before any change are passed *)
  let rec back (at : int option) : int option =
    match t.undos with
    | Inserted (pos, len) :: rest -> t.undos <- rest; ignore (delete_ t pos len); back (Some pos)
    | Deleted (pos, s) :: rest -> t.undos <- rest; insert_ t pos s; back (Some (pos + String.length s))
    | Boundary :: rest when at = None -> t.undos <- rest; back None
    | Boundary :: _ | [] -> at in
  back None

(*****************************************************************************)
(* Search *)
(*****************************************************************************)

let search_forward (t : t) (re : Regex.t) (pos : int) : (int * int) array option = Regex.exec re (to_string t) pos

(* Regex goes forward only: the matches from the start, one after the
 * other, until one starts at pos or after *)
let search_backward (t : t) (re : Regex.t) (pos : int) : (int * int) array option =
  let s = to_string t in
  let rec last (from : int) (found : (int * int) array option) : (int * int) array option =
    match Regex.exec re s from with
    | Some m when fst m.(0) < pos -> last (fst m.(0) + 1) (Some m)
    | _ -> found in
  last 0 None
