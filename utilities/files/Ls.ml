(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-ls: Plan 9's ls (principia's utilities/files/ls.c), its output
 * byte for byte: a directory's entries, or a file's own, one a line,
 * sorted by name. What a line says is 9P's entry (Sys_plan9.dir), so
 * on another system it is what Unix's stat can fill of it.
 *
 * Its options: -l the long line (the mode, the device's letter and
 * number, the owner and the group, the length, the date), -d a
 * directory itself and not its entries, -s the size in KB before, -m
 * who wrote it last, -q the qid, -T the temporary bit, -F a / after a
 * directory and a * after what can be run, -t by time and not by name
 * (-u: the time read, not written), -r the order reversed, -n not
 * sorted, -p no directory before the names, -Q the names never quoted.
 *
 * The dates are GMT's: ls.c's ctime reads /env/timezone, not read here. *)

type caps = < Cap.readdir; Cap.stdout; Cap.stderr >

exception Usage

type options = {
  mutable d : bool; mutable l : bool; mutable m : bool; mutable n : bool; mutable p : bool; mutable q : bool;
  mutable big_q : bool; mutable r : bool; mutable s : bool; mutable t : bool; mutable big_t : bool; mutable u : bool;
  mutable big_f : bool;
}

(* the columns' widths: the widest so far, of all that was listed *)
type widths = { mutable ws : int; mutable wq : int; mutable wv : int; mutable wu : int; mutable wm : int; mutable wl : int; mutable wg : int }

(* an entry, and the directory to say before its name, if any *)
type line = { dir : Sys_plan9.dir; prefix : string option }

(* %q: quoted when empty, or with a space, a control character or a quote *)
let quote name =
  if name <> "" && not (String.exists (fun c -> c <= ' ' || c = '\'') name) then name
  else "'" ^ String.concat "''" (String.split_on_char '\'' name) ^ "'"

let pad_left w text = String.make (max 0 (w - String.length text)) ' ' ^ text
let pad_right w text = text ^ String.make (max 0 (w - String.length text)) ' '

(* %M: d for a directory (a for append-only, A for authentication), l
 * for exclusive use, then the three rwx *)
let mode (d : Sys_plan9.dir) =
  let has bit = d.mode_type land bit <> 0 in
  let rwx k = let b = (d.perm lsr k) land 7 in
    (if b land 4 <> 0 then "r" else "-") ^ (if b land 2 <> 0 then "w" else "-") ^ (if b land 1 <> 0 then "x" else "-") in
  (if has Sys_plan9.dmdir then "d" else if has Sys_plan9.dmappend then "a" else if has Sys_plan9.dmauth then "A" else "-")
  ^ (if has Sys_plan9.dmexcl then "l" else "-") ^ rwx 6 ^ rwx 3 ^ rwx 0

(* the month and the day, then the hour, or the year for a time more
 * than 6 months ago or a day ahead (12 characters) *)
let date ~now t =
  let tm = Unix.gmtime t in
  let month = String.sub "JanFebMarAprMayJunJulAugSepOctNovDec" (3 * tm.Unix.tm_mon) 3 in
  if t < now -. (180.0 *. 86400.0) || now +. 86400.0 < t then Printf.sprintf "%s %2d  %d" month tm.Unix.tm_mday (tm.Unix.tm_year + 1900)
  else Printf.sprintf "%s %2d %02d:%02d" month tm.Unix.tm_mday tm.Unix.tm_hour tm.Unix.tm_min

let kb (d : Sys_plan9.dir) = string_of_int ((d.length + 1023) / 1024)

let widen o w (d : Sys_plan9.dir) =
  let len s = String.length s in
  if o.s then w.ws <- max w.ws (len (kb d));
  if o.q then w.wq <- max w.wq (len (Int64.to_string d.qid_vers));
  if o.m then w.wm <- max w.wm (len (quote d.muid) + 2);
  if o.l then begin
    w.wv <- max w.wv (len (string_of_int d.dev));
    w.wu <- max w.wu (len (quote d.uid));
    w.wg <- max w.wg (len (quote d.gid));
    w.wl <- max w.wl (len (string_of_int d.length))
  end

let format o w ~now (d : Sys_plan9.dir) name =
  let b = Buffer.create 128 in
  let add = Buffer.add_string b in
  if o.s then add (pad_left w.ws (kb d) ^ " ");
  if o.m then add (pad_right (w.wm + 1) ("[" ^ quote d.muid ^ "] "));
  if o.q then add (Printf.sprintf "(%016Lx %s %02x) " d.qid_path (pad_left w.wq (Int64.to_string d.qid_vers)) d.qid_type);
  if o.big_t then add (if d.mode_type land Sys_plan9.dmtmp <> 0 then "t " else "- ");
  if o.l then
    add (Printf.sprintf "%s %c %s %s %s %s %s " (mode d) d.dev_type (pad_left w.wv (string_of_int d.dev))
           (pad_right w.wu (quote d.uid)) (pad_right w.wg (quote d.gid)) (pad_left w.wl (string_of_int d.length))
           (date ~now (if o.u then d.atime else d.mtime)));
  add (if o.big_q then name else quote name);
  if o.big_f then add (if d.qid_type land Sys_plan9.dmdir <> 0 then "/" else if d.perm land 0o111 <> 0 then "*" else "");
  add "\n";
  Buffer.contents b

(* by time (the newest first) or by name, a directory's name counting
 * before its entries'; what is equal stays in its order *)
let compare_lines o (ka, (a : line)) (kb, (b : line)) =
  let c =
    if o.t then compare (if o.u then b.dir.atime else b.dir.mtime) (if o.u then a.dir.atime else a.dir.mtime)
    else match a.prefix, b.prefix with
      | Some pa, Some pb -> let c = compare pa pb in if c = 0 then compare a.dir.name b.dir.name else c
      | Some pa, None -> let c = compare pa b.dir.name in if c = 0 then 1 else c
      | None, Some pb -> let c = compare a.dir.name pb in if c = 0 then -1 else c
      | None, None -> compare a.dir.name b.dir.name in
  let c = if c = 0 then compare (ka : int) kb else c in
  if o.r then -c else c

(* the lines so far, sorted and printed *)
let output (caps : < caps; .. >) o w ~now (lines : line list ref) =
  let numbered = List.mapi (fun k line -> k, line) (List.rev !lines) in
  let sorted = List.map snd (if o.n then numbered else List.sort (compare_lines o) numbered) in
  List.iter (fun line -> widen o w line.dir) sorted;
  Console.print caps (String.concat "" (List.map (fun line ->
    match line.prefix with
    | Some prefix when not o.p -> format o w ~now line.dir ((if prefix = "/" then "" else prefix) ^ "/" ^ line.dir.name)
    | _ -> format o w ~now line.dir line.dir.name) sorted));
  lines := []

(* slashes compressed, the last one removed *)
let clean name =
  let b = Buffer.create (String.length name) in
  String.iteri (fun k c -> if not (c = '/' && k > 0 && name.[k - 1] = '/') then Buffer.add_char b c) name;
  let s = Buffer.contents b in
  let rec strip s = if String.length s > 1 && s.[String.length s - 1] = '/' then strip (String.sub s 0 (String.length s - 1)) else s in
  strip s

(* a file's line, or a directory's entries'; false when it could not be read *)
let ls (caps : < caps; .. >) o w ~now lines ~multi name =
  try
    let d : Sys_plan9.dir = Sys_plan9.dirstat caps name in
    if d.qid_type land Sys_plan9.dmdir <> 0 && not o.d then begin
      output caps o w ~now lines;
      let entries = Sys_plan9.dirread caps name in
      let prefix = if multi then Some (clean name) else None in
      lines := List.rev_map (fun dir -> { dir; prefix }) entries;
      output caps o w ~now lines
    end
    else begin
      let name = clean name in
      let prefix = match String.rindex_opt name '/' with Some k -> Some (String.sub name 0 k) | None -> None in
      lines := { dir = d; prefix } :: !lines
    end;
    true
  with Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "ls: %s: %s\n" name (Unix.error_message e)); false

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
  let o = { d = false; l = false; m = false; n = false; p = false; q = false; big_q = false; r = false; s = false; t = false;
            big_t = false; u = false; big_f = false } in
  let rec options = function
    | "--" :: rest -> rest
    | a :: rest when String.length a > 1 && a.[0] = '-' ->
        String.iteri (fun k c ->
          if k > 0 then match c with
            | 'F' -> o.big_f <- true | 'd' -> o.d <- true | 'l' -> o.l <- true | 'm' -> o.m <- true | 'n' -> o.n <- true
            | 'p' -> o.p <- true | 'q' -> o.q <- true | 'Q' -> o.big_q <- true | 'r' -> o.r <- true | 's' -> o.s <- true
            | 't' -> o.t <- true | 'T' -> o.big_t <- true | 'u' -> o.u <- true
            | _ -> raise Usage) a;
        options rest
    | rest -> rest in
  let files = options (List.tl (Array.to_list argv)) in
  let w = { ws = 0; wq = 0; wv = 0; wu = 0; wm = 0; wl = 0; wg = 0 } and lines = ref [] in
  let now = if o.l then Unix.time () else 0.0 in
  let ok = match files with
    | [] -> ls caps o w ~now lines ~multi:false "."
    | _ -> List.fold_left (fun ok file -> ls caps o w ~now lines ~multi:true file && ok) true files in
  output caps o w ~now lines;
  if ok then Exit.OK else Exit.Err "errors"
  with Usage -> Console.eprint caps "usage: ls [-dlmnpqrstuFQT] [file ...]\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
