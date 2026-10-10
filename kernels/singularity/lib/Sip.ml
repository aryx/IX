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
let time () : int = call 14 0 0 0 0

type process = int

let create (name : string) : process option =
  let h = call_s 3 name (String.length name) 0 0 in
  if h < 0 then None else Some h

let start (p : process) : unit = done_ "start" (call 4 p 0 0 0)
let join (p : process) : int = held (call 5 p 0 0 0)

type endpoint = int

let channel (c : Contract.t) : endpoint * endpoint =
  let s = Contract.encode c in
  let a = call_s 6 s (String.length s) 0 0 in
  if a < 0 then failwith "Sip.channel";
  (a, word 1)

let is (e : endpoint) (contract : string) (side : Contract.side) : bool =
  held (call_s 15 contract (String.length contract) e (match side with Imp -> 0 | Exp -> 1)) = 0

let give (p : process) (e : endpoint) : unit = done_ "give" (call 7 p e 0 0)
let given (i : int) : endpoint = i

type block = int

(* sip.c's table of the blocks owned: a handle noted with the address
 * in the last answer's words, forgotten; then what is done to a
 * block's bytes, there, with no call of the kernel *)
external block_take : int -> int -> unit = "sip_block_take"
external block_drop : int -> unit = "sip_block_drop"
external block_size : int -> int = "sip_block_size"
external block_get : int -> int -> int = "sip_block_get"
external block_set : int -> int -> int -> int = "sip_block_set"
external block_blit : int -> int -> Bytes.t -> int -> int -> int = "sip_block_blit"

type carried =
  | Nothing
  | Block of block
  | Endpoint of endpoint

type message = {
  tag : int;
  value : int;
  carried : carried;
}

let sent (r : int) : unit = if held r < 0 then raise Closed
let send (e : endpoint) (tag : int) (value : int) : unit = sent (call 8 e tag value (-1))
let send_block (e : endpoint) (tag : int) (value : int) (b : block) : unit =
  sent (call 8 e tag value b);
  block_drop b
let send_endpoint (e : endpoint) (tag : int) (value : int) (x : endpoint) : unit = sent (call 8 e tag value x)

let receive (e : endpoint) : message =
  let tag = held (call 9 e 0 0 0) in
  if tag < 0 then raise Closed;
  let h = word 2 in
  let carried =
    if h < 0 then Nothing
    else if word 5 = 1 then begin block_take h 3; Block h end
    else Endpoint h
  in
  { tag; value = word 1; carried }

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
  block_take b 1;
  b

let free (b : block) : unit = ignore (held (call 13 b 0 0 0)); block_drop b

(* an answer of sip.c's: -2 not held, -1 outside the block *)
let inside (r : int) : int = if held r = -1 then invalid_arg "Sip: outside the block, or the registers" else r

let size (b : block) : int = held (block_size b)
let get (b : block) (i : int) : char = Char.chr (inside (block_get b i))
let set (b : block) (i : int) (c : char) : unit = ignore (inside (block_set b i (Char.code c)))

let sub (b : block) (off : int) (n : int) : string =
  if n < 0 then invalid_arg "Sip.sub";
  let s = Bytes.create n in
  ignore (inside (block_blit b off s 0 n));
  Bytes.unsafe_to_string s

(* (a negative place in the bytes says: into the block) *)
let write (b : block) (off : int) (s : string) : unit =
  ignore (inside (block_blit b off (Bytes.unsafe_of_string s) (-1) (String.length s)))

type registers = int
type interrupt = int

let granted_registers (h : int) : registers = h
let granted_interrupt (h : int) : interrupt = h
let io_read (r : registers) (off : int) : int = inside (call 16 r off 0 0)
let io_write (r : registers) (off : int) (v : int) : unit = ignore (inside (call 17 r off v 0))
let wait (i : interrupt) : unit = ignore (held (call 18 i 0 0 0))

let info (b : block) (programs : bool) : string =
  let n = held (call 19 b (if programs then 1 else 0) 0 0) in
  sub b 0 (max n 0)

let stop (p : process) : unit = ignore (held (call 20 p 0 0 0))
