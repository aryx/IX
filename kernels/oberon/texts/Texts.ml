(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Texts.mli *)

let text_tag = 0xf1

(* a stretch of a file: [size] bytes from [start], in one looks *)
type piece = { source : Files.t; start : int; size : int; font : Fonts.t; color : int; offset : int }
type op = Replace | Insert | Delete | Unmark

type t = {
  mutable pieces : piece list;
  mutable len : int;
  mutable changed : bool;
  mutable notify : t -> op -> int -> int -> unit;
}

type buffer = { mutable stretch : piece list; mutable blen : int }

(*****************************************************************************)
(* Filing *)
(*****************************************************************************)

(* A text's file (Texts.Mod: TextBlock = TextTag offset run {run} "0"
 * len {AsciiCode}; run = fnt [name] col voff len): after the tag, where
 * the characters start; the runs, each a font's number (its name the
 * first time the number is used), a colour, an offset, a length; a
 * zero, the text's length; the characters. *)
let load (f : Files.t) : piece list * int =
  let r = Files.set f 1 in
  let start = ref (Files.read_int r) in
  let fonts = Hashtbl.create 8 in
  let rec runs acc =
    let n = Files.read_byte r in
    if n = 0 then List.rev acc
    else begin
      if not (Hashtbl.mem fonts n) then Hashtbl.replace fonts n (Fonts.this (Files.read_string r));
      let color = Files.read_byte r in
      let offset = Files.read_byte r in
      let offset = if offset >= 128 then offset - 256 else offset in
      let size = Files.read_int r in
      let p = { source = f; start = !start; size; font = Hashtbl.find fonts n; color; offset } in
      start := !start + size;
      runs (p :: acc)
    end
  in
  let pieces = runs [] in
  pieces, Files.read_int r

let open_ name =
  let pieces, len =
    match Files.old name with
    | None -> [], 0
    | Some f ->
        if Files.length f > 0 && Char.code (Bytes.get f.data 0) = text_tag then load f
        else if Files.length f = 0 then [], 0
        else [ { source = f; start = 0; size = Files.length f; font = Fonts.default (); color = 1; offset = 0 } ], Files.length f
  in
  { pieces; len; changed = false; notify = (fun _ _ _ _ -> ()) }

(* the runs (pieces of the same looks one after the other are one
 * run), each font's name the first time; the characters after them,
 * their place written where the runs start *)
let store (w : Files.rider) (t : t) =
  let place = w.pos in
  Files.write_int w 0;
  let fonts = ref [] in
  let rec runs (pieces : piece list) =
    match pieces with
    | [] -> ()
    | p :: rest ->
        let same (q : piece) = q.font == p.font && q.color = p.color && q.offset = p.offset in
        let rec take n (l : piece list) = match l with q :: l' when same q -> take (n + q.size) l' | _ -> n, l in
        let size, rest = take p.size rest in
        (match List.assq_opt p.font !fonts with
         | Some n -> Files.write_byte w n
         | None ->
             let n = List.length !fonts + 1 in
             fonts := (p.font, n) :: !fonts;
             Files.write_byte w n; Files.write_string w p.font.name);
        Files.write_byte w p.color; Files.write_byte w p.offset; Files.write_int w size;
        runs rest
  in
  runs t.pieces;
  Files.write_byte w 0; Files.write_int w t.len;
  let chars = w.pos in
  List.iter (fun (p : piece) -> for i = 0 to p.size - 1 do Files.write w (Bytes.get p.source.data (p.start + i)) done) t.pieces;
  Files.write_int (Files.set w.file place) chars;
  t.changed <- false;
  t.notify t Unmark 0 0

let close (t : t) name =
  let f = Files.new_ name in
  let w = Files.set f 0 in
  Files.write_byte w text_tag;
  store w t;
  Files.register f

(*****************************************************************************)
(* Editing *)
(*****************************************************************************)

let open_buf () = { stretch = []; blen = 0 }

(* the pieces before a position, and those from it: the piece that has
 * it is cut in two *)
let rec split (pieces : piece list) pos =
  match pieces with
  | [] -> [], []
  | p :: rest ->
      if pos <= 0 then [], pieces
      else if pos >= p.size then let before, after = split rest (pos - p.size) in p :: before, after
      else [ { p with size = pos } ], { p with start = p.start + pos; size = p.size - pos } :: rest

(* two stretches joined; the pieces at the seam made one when the
 * second goes on where the first ends, in the same looks (what is
 * typed, a character at a time, stays one piece) *)
let join (a : piece list) (b : piece list) =
  match List.rev a, b with
  | p :: before, q :: after when p.source == q.source && q.start = p.start + p.size && p.font == q.font && p.color = q.color && p.offset = q.offset ->
      List.rev_append before ({ p with size = p.size + q.size } :: after)
  | _ -> a @ b

let save (t : t) beg end_ (b : buffer) =
  let end_ = min end_ t.len in
  let _, from = split t.pieces beg in
  let stretch, _ = split from (end_ - beg) in
  b.stretch <- join b.stretch stretch;
  b.blen <- b.blen + (end_ - beg)

let copy (src : buffer) (dst : buffer) =
  dst.stretch <- join dst.stretch src.stretch;
  dst.blen <- dst.blen + src.blen

let insert (t : t) pos (b : buffer) =
  let before, after = split t.pieces pos in
  let n = b.blen in
  t.pieces <- join (join before b.stretch) after;
  t.len <- t.len + n;
  b.stretch <- []; b.blen <- 0;
  t.changed <- true;
  t.notify t Insert pos (pos + n)

let append (t : t) b = insert t t.len b

let delete (t : t) beg end_ (b : buffer) =
  let end_ = min end_ t.len in
  let before, from = split t.pieces beg in
  let stretch, after = split from (end_ - beg) in
  b.stretch <- stretch; b.blen <- end_ - beg;
  t.pieces <- join before after;
  t.len <- t.len - (end_ - beg);
  t.changed <- true;
  t.notify t Delete beg end_

let change_looks (t : t) beg end_ font =
  let end_ = min end_ t.len in
  let before, from = split t.pieces beg in
  let stretch, after = split from (end_ - beg) in
  t.pieces <- before @ List.map (fun (p : piece) -> { p with font = font }) stretch @ after;
  t.changed <- true;
  t.notify t Replace beg end_

let attributes (t : t) pos =
  match split t.pieces pos with
  | _, (p : piece) :: _ -> p.font
  | _ -> Fonts.default ()

(*****************************************************************************)
(* Reading *)
(*****************************************************************************)

type reader = {
  mutable eot : bool;
  mutable fnt : Fonts.t;
  mutable col : int;
  mutable voff : int;
  mutable ahead : piece list;
  mutable off : int;
  mutable at : int;
}

let open_reader (t : t) pos =
  let pos = max 0 (min pos t.len) in
  (* (no piece cut: the one that has pos, and where in it) *)
  let rec find (pieces : piece list) n = match pieces with p :: rest when n >= p.size -> find rest (n - p.size) | _ -> pieces, n in
  let ahead, off = find t.pieces pos in
  { eot = false; fnt = Fonts.default (); col = 1; voff = 0; ahead; off; at = pos }

let read (r : reader) =
  match r.ahead with
  | [] -> r.eot <- true; '\000'
  | p :: rest ->
      let ch = Bytes.get p.source.data (p.start + r.off) in
      r.fnt <- p.font; r.col <- p.color; r.voff <- p.offset;
      r.at <- r.at + 1;
      if r.off + 1 = p.size then begin r.ahead <- rest; r.off <- 0 end else r.off <- r.off + 1;
      ch

let pos (r : reader) = r.at

(*****************************************************************************)
(* Writing *)
(*****************************************************************************)

type writer = { mutable buf : buffer; mutable wfnt : Fonts.t; mutable wcol : int; mutable wvoff : int; file : Files.t }

let open_writer () = { buf = open_buf (); wfnt = Fonts.default (); wcol = 1; wvoff = 0; file = Files.new_ "" }

(* a character at the end of the writer's file, and a piece of one
 * character for it (join makes one of them and the last, when it goes on) *)
let write (w : writer) ch =
  let at = Files.length w.file in
  Files.write (Files.set w.file at) ch;
  w.buf.stretch <- join w.buf.stretch [ { source = w.file; start = at; size = 1; font = w.wfnt; color = w.wcol; offset = w.wvoff } ];
  w.buf.blen <- w.buf.blen + 1

let write_string w s = String.iter (write w) s
let write_ln w = write w '\r'
let write_int w n width =
  let s = string_of_int n in
  for _i = String.length s + 1 to width do write w ' ' done;
  write_string w s

(*****************************************************************************)
(* Scanning *)
(*****************************************************************************)

type symbol = Name of string | String of string | Int of int | Char of char
type scanner = { reader : reader; mutable next_ch : char; mutable line : int; mutable sym : symbol }

let open_scanner t pos = { reader = open_reader t pos; next_ch = ' '; line = 0; sym = Char ' ' }

let letter c = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
let digit c = c >= '0' && c <= '9'

let scan (s : scanner) =
  let next () = s.next_ch <- read s.reader in
  while s.next_ch = ' ' || s.next_ch = '\t' || s.next_ch = '\r' do
    if s.next_ch = '\r' then s.line <- s.line + 1;
    next ()
  done;
  let b = Buffer.create 32 in
  let rec while_ pred = if pred s.next_ch && not s.reader.eot then begin Buffer.add_char b s.next_ch; next (); while_ pred end in
  let ch = s.next_ch in
  if letter ch then begin
    while_ (fun c -> letter c || digit c || c = '.');
    s.sym <- Name (Buffer.contents b)
  end
  else if ch = '"' then begin
    next ();
    while_ (fun c -> c <> '"' && c >= ' ');
    next ();
    s.sym <- String (Buffer.contents b)
  end
  else if digit ch || ch = '-' then begin
    if ch = '-' then next ();
    if not (digit s.next_ch) then s.sym <- Char '-'
    else begin
      while_ (fun c -> digit c || (c >= 'A' && c <= 'F'));
      let digits = Buffer.contents b in
      let n = if s.next_ch = 'H' then begin next (); int_of_string ("0x" ^ digits) end else (match int_of_string_opt digits with Some n -> n | None -> 0) in
      s.sym <- Int (if ch = '-' then - n else n)
    end
  end
  else begin
    s.sym <- Char ch;
    next ()
  end
