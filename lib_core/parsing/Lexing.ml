(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Lexing.mli *)

type position = { pos_fname : string; pos_lnum : int; pos_bol : int; pos_cnum : int }
let dummy_pos = { pos_fname = ""; pos_lnum = 0; pos_bol = 0; pos_cnum = -1 }

type lexbuf = {
  refill_buff : lexbuf -> unit;
  mutable lex_buffer : bytes;
  mutable lex_buffer_len : int;
  mutable lex_abs_pos : int;
  mutable lex_start_pos : int;
  mutable lex_curr_pos : int;
  mutable lex_eof_reached : bool;
  mutable lex_start_p : position;
  mutable lex_curr_p : position;
}

let make refill buffer =
  let p = { pos_fname = ""; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 } in
  { refill_buff = refill; lex_buffer = buffer; lex_buffer_len = Bytes.length buffer; lex_abs_pos = 0; lex_start_pos = 0;
    lex_curr_pos = 0; lex_eof_reached = false; lex_start_p = p; lex_curr_p = p }

let from_string s = make (fun b -> b.lex_eof_reached <- true) (Bytes.of_string s)

(* more characters: those before the current token dropped, the new
 * ones after what is left *)
let from_function read =
  let chunk = Bytes.create 1024 in
  make (fun b ->
    let n = read chunk 1024 in
    if n = 0 then b.lex_eof_reached <- true
    else begin
      let kept = b.lex_buffer_len - b.lex_start_pos in
      b.lex_buffer <- Bytes.cat (Bytes.sub b.lex_buffer b.lex_start_pos kept) (Bytes.sub chunk 0 n);
      b.lex_buffer_len <- kept + n;
      b.lex_abs_pos <- b.lex_abs_pos + b.lex_start_pos;
      b.lex_curr_pos <- b.lex_curr_pos - b.lex_start_pos;
      b.lex_start_pos <- 0
    end) Bytes.empty

let from_channel ic = from_function (fun buf n -> input ic buf 0 n)

let lexeme b = Bytes.sub_string b.lex_buffer b.lex_start_pos (b.lex_curr_pos - b.lex_start_pos)
let lexeme_char b i = Bytes.get b.lex_buffer (b.lex_start_pos + i)
let lexeme_start b = b.lex_start_p.pos_cnum
let lexeme_end b = b.lex_curr_p.pos_cnum
let lexeme_start_p b = b.lex_start_p
let lexeme_end_p b = b.lex_curr_p

let new_line b =
  let p = b.lex_curr_p in
  b.lex_curr_p <- { p with pos_lnum = p.pos_lnum + 1; pos_bol = p.pos_cnum }

type tables = { trans : string; accept : string }

(* The DFA run from the current position, the last state that accepted
 * remembered with where it was: the longest match. The end of the
 * input is a character of its own (256), read without moving. *)
let engine (t : tables) state b =
  (* from here to the end of the buffer nothing is dropped by a refill:
   * the token starts here *)
  b.lex_start_pos <- b.lex_curr_pos;
  (* the last match: its clause, its length (a refill moves the buffer) *)
  let last = ref (-1) and last_len = ref 0 in
  let rec go state =
    (match String.get_uint16_le t.accept (2 * state) with 0 -> () | a -> last := a - 1; last_len := b.lex_curr_pos - b.lex_start_pos);
    (* a state with no way out reads nothing more (ocamllex's too): the
     * token of a line's end is given before the next line is asked for *)
    let rec leaves c = c <= 256 && (String.get_uint16_le t.trans (2 * ((257 * state) + c)) <> 0 || leaves (c + 1)) in
    let stuck = b.lex_curr_pos >= b.lex_buffer_len && not b.lex_eof_reached && not (leaves 0) in
    if b.lex_curr_pos >= b.lex_buffer_len && not b.lex_eof_reached && not stuck then b.refill_buff b;
    let at_end = b.lex_curr_pos >= b.lex_buffer_len in
    if stuck then ()
    (* refilled, and still nothing: the function gave less than asked, not the end *)
    else if at_end && not b.lex_eof_reached then go_same state
    else begin
      let c = if at_end then 256 else Char.code (Bytes.get b.lex_buffer b.lex_curr_pos) in
      match String.get_uint16_le t.trans (2 * ((257 * state) + c)) with
      | 0 -> ()
      | next ->
          if at_end then (match String.get_uint16_le t.accept (2 * (next - 1)) with 0 -> () | a -> last := a - 1; last_len := b.lex_curr_pos - b.lex_start_pos)
          else begin b.lex_curr_pos <- b.lex_curr_pos + 1; go (next - 1) end
    end
  and go_same state = go state in
  go state;
  if !last < 0 then failwith "lexing: empty token";
  b.lex_curr_pos <- b.lex_start_pos + !last_len;
  b.lex_start_p <- b.lex_curr_p;
  b.lex_curr_p <- { b.lex_curr_p with pos_cnum = b.lex_abs_pos + b.lex_curr_pos };
  !last

(* r as x, by a second look at the lexeme *)
type regexp =
  | Chars of string
  | Eof
  | Eps
  | Seq of regexp * regexp
  | Alt of regexp * regexp
  | Star of regexp
  | Bind of int * regexp

(* The lexeme matched again, whole, each Bind's span noted: by trying,
 * the first alternative first and a repetition as long as it can be,
 * then less (a lexeme is short, and most regexps have one way). A span
 * noted on a way given up is forgotten. *)
let captures re n b =
  let s = b.lex_buffer and stop = b.lex_curr_pos in
  let spans = Array.make n (-1, -1) in
  let rec go re i k =
    match re with
    | Chars set -> i < stop && (let c = Char.code (Bytes.get s i) in Char.code set.[c lsr 3] land (1 lsl (c land 7)) <> 0) && k (i + 1)
    | Eof -> i = stop && k i
    | Eps -> k i
    | Seq (x, y) -> go x i (fun j -> go y j k)
    | Alt (x, y) -> go x i k || go y i k
    | Star x -> go x i (fun j -> j > i && go re j k) || k i
    | Bind (v, x) -> go x i (fun j -> let old = spans.(v) in spans.(v) <- (i, j); k j || (spans.(v) <- old; false))
  in
  if not (go re b.lex_start_pos (fun j -> j = stop)) then failwith "lexing: a token's parts";
  spans

let sub b spans v = let i, j = spans.(v) in Bytes.sub_string b.lex_buffer i (j - i)
let sub_opt b spans v = if fst spans.(v) < 0 then None else Some (sub b spans v)
let sub_char b spans v = Bytes.get b.lex_buffer (fst spans.(v))
let sub_char_opt b spans v = if fst spans.(v) < 0 then None else Some (sub_char b spans v)
