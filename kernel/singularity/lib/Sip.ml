(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Sip.mli *)

exception Not_held
exception Closed

(* Abi's calls: a number and four integers; the same, the first the
 * address of a string's bytes; a word of the last answer (sip.c) *)
external call : int -> int -> int -> int -> int -> int = "sip_call"
external call_s : int -> string -> int -> int -> int -> int = "sip_call_s"
external word : int -> int = "sip_word"

(* an answer: -2 is a handle that is not one; -1 is said by [what] *)
let held (r : int) : int = if r = -2 then raise Not_held else r
let done_ (what : string) (r : int) : unit = if held r < 0 then failwith ("Sip." ^ what)

let yield () : unit = ignore (call 2 0 0 0 0)
let time () : int = call 17 0 0 0 0

type process = int

let create (name : string) : process option =
  let h = call_s 3 name (String.length name) 0 0 in
  if h < 0 then None else Some h

let start (p : process) : unit = done_ "start" (call 4 p 0 0 0)
let join (p : process) : int = held (call 5 p 0 0 0)

type endpoint = int

let channel () : endpoint * endpoint =
  let a = call 6 0 0 0 0 in
  if a < 0 then failwith "Sip.channel";
  (a, word 1)

let give (p : process) (e : endpoint) : unit = done_ "give" (call 7 p e 0 0)
let given (i : int) : endpoint = i

type block = int

type message = {
  tag : int;
  value : int;
  block : block option;
}

let sent (r : int) : unit = if held r < 0 then raise Closed
let send (e : endpoint) (tag : int) (value : int) : unit = sent (call 8 e tag value (-1))
let send_block (e : endpoint) (tag : int) (value : int) (b : block) : unit = sent (call 8 e tag value b)

let receive (e : endpoint) : message =
  let tag = held (call 9 e 0 0 0) in
  if tag < 0 then raise Closed;
  { tag; value = word 1; block = (if word 2 < 0 then None else Some (word 2)) }

let select (l : endpoint list) : int =
  match l with
  | [ a ] -> held (call 10 1 a 0 0)
  | [ a; b ] -> held (call 10 2 a b 0)
  | [ a; b; c ] -> held (call 10 3 a b c)
  | _ -> invalid_arg "Sip.select"

let close (e : endpoint) : unit = ignore (held (call 11 e 0 0 0))

let alloc (n : int) : block =
  let b = call 12 n 0 0 0 in
  if b < 0 then failwith "Sip.alloc";
  b

let free (b : block) : unit = ignore (held (call 13 b 0 0 0))
let size (b : block) : int = held (call 14 b 0 0 0)

let read (b : block) : string =
  let n = size b in
  let s = Bytes.create n in
  done_ "read" (call_s 15 (Bytes.unsafe_to_string s) n b 0);
  Bytes.unsafe_to_string s

let write (b : block) (off : int) (s : string) : unit = done_ "write" (call_s 16 s (String.length s) b off)
