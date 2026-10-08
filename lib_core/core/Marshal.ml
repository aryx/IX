(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* A value as bytes, and back: OCaml's format (ocaml-light's too). 20
 * bytes (the magic number, the data's length, the blocks' count, the
 * words they take on 32 and on 64 bits), then the value, depth first,
 * each thing a byte's code and what follows, the high byte first:
 *
 *   0x80 + tag + size * 16     a block of a few fields, then its fields
 *   0x40 + n                   an integer under 64
 *   0x20 + length              a string under 32 bytes, then its bytes
 *   0x00, 0x01, 0x02, 0x03     an integer of 1, 2, 4, 8 bytes
 *   0x04, 0x05, 0x06           a block met before: how many blocks ago,
 *                              in 1, 2, 4 bytes (what is shared stays
 *                              shared, and a cycle ends)
 *   0x08                       a block: size * 1024 + tag in 4 bytes
 *   0x09, 0x0A                 a string: its length in 1, 4 bytes
 *   0x0B, 0x0C                 a float: its 8 bytes, the high or the
 *                              low one first
 *   0x12, 0x18, 0x19           a custom block: its name, "_j" an int64,
 *                              "_i" an int32, then its bytes
 *
 * The same bytes as OCaml's wherever a value is the same blocks in
 * both; not a constructor's inline record (here a block of its own),
 * an array of floats (here boxed), a closure (refused).
 *
 * old: 478 lines of C in the runtime, its tables in memory of their own
 * (mmap); here they are values, which the collector moves: see [seen].
 * Reading and writing are 4 to 6 times slower than the C's (mini-cc's):
 * a link of mini-ml 16% longer, ix built by ix 12% (plan_ml_features.md,
 * 3, has the numbers). Tried, and not faster in that build: the
 * writer's bytes its own (not a Buffer's), the collection told by a
 * block's address (not a call), no bound checked, fewer calls a value. *)

type extern_flags =
    No_sharing
  | Closures

let header_size = 20
let magic = "\x84\x95\xA6\xBE"

(* mini-ml's tags (the runtime's mlvalues.h), with Obj's two *)
let closure_tag = 247
let int32_tag = 254
let int64_tag = 255

(* the i-th of the header's five numbers *)
let header_int (s : string) (ofs : int) (i : int) : int =
  Int32.to_int (String.get_int32_be s (ofs + 4 * i))

(*****************************************************************************)
(* Writing *)
(*****************************************************************************)

(* The blocks written, each with its number: a hash table by a block's
 * address, the only name a block has. A collection moves the blocks, so
 * every slot is computed anew after one ([epoch] tells), and nothing
 * may be allocated between a slot's computation and its use. *)
type seen = {
  mutable blocks : Obj.t array;  (* a slot: a block, or 0 when free *)
  mutable numbers : int array;
  mutable count : int;
  mutable epoch : int;
}

external collections : unit -> int = "gc_collections"

(* (an address's bits mixed: blocks made together are neighbours, and
 * two runs of them over the same slots are long searches; the C's
 * table, by the address alone, took 28 s for a list on arm) *)
let hash (v : Obj.t) : int =
  let h = ((Obj.magic v : int) lsr 2) * 0x9E3779B in
  h lxor (h lsr 15)

(* where v is from slot i on, or the free slot it goes to *)
let rec probe (blocks : Obj.t array) (v : Obj.t) (i : int) : int =
  let b = blocks.(i) in
  if Obj.is_int b || b == v then i
  else probe blocks v ((i + 1) land (Array.length blocks - 1))

let slot (blocks : Obj.t array) (v : Obj.t) : int =
  probe blocks v (hash v land (Array.length blocks - 1))

(* the table in n slots (a power of 2), by today's addresses *)
let rehash (t : seen) (n : int) : unit =
  let blocks = Array.make n (Obj.repr 0) and numbers = Array.make n 0 in
  t.epoch <- collections ();
  for i = 0 to Array.length t.blocks - 1 do
    let b = t.blocks.(i) in
    if not (Obj.is_int b) then begin
      let j = slot blocks b in
      blocks.(j) <- b;
      numbers.(j) <- t.numbers.(i)
    end
  done;
  t.blocks <- blocks;
  t.numbers <- numbers

(* v's number if it was written; else None, and it is given the next *)
let number (t : seen) (v : Obj.t) : int option =
  if t.count * 2 >= Array.length t.blocks then rehash t (2 * Array.length t.blocks)
  else if t.epoch <> collections () then rehash t (Array.length t.blocks);
  let i = slot t.blocks v in
  if Obj.is_int t.blocks.(i) then begin
    t.blocks.(i) <- v;
    t.numbers.(i) <- t.count;
    t.count <- t.count + 1;
    None
  end
  else Some t.numbers.(i)

type writer = {
  out : Buffer.t;
  seen : seen;
  (* the words the blocks take when read, for the header *)
  mutable words32 : int;
  mutable words64 : int;
}

(* n's low bytes, the high one first *)
let put (w : writer) (n : int) (bytes : int) : unit =
  for i = bytes - 1 downto 0 do
    Buffer.add_uint8 w.out (n asr (8 * i))
  done

let words (w : writer) (on32 : int) (on64 : int) : unit =
  w.words32 <- w.words32 + on32;
  w.words64 <- w.words64 + on64

(* n is a signed number of that many bits *)
let fits (n : int) (bits : int) : bool =
  let high = n asr (bits - 1) in
  high = 0 || high = -1

let write_int (w : writer) (n : int) : unit =
  if n >= 0 && n < 64 then put w (0x40 + n) 1
  else if fits n 8 then (put w 0x00 1; put w n 1)
  else if fits n 16 then (put w 0x01 1; put w n 2)
  (* 31 bits, as OCaml: what a machine of 32 bits can read *)
  else if fits n 31 then (put w 0x02 1; put w n 4)
  else (put w 0x03 1; put w n 8)

let write_shared (w : writer) (ago : int) : unit =
  if ago < 256 then (put w 0x04 1; put w ago 1)
  else if ago < 65536 then (put w 0x05 1; put w ago 2)
  else (put w 0x06 1; put w ago 4)

let write_string (w : writer) (s : string) : unit =
  let n = String.length s in
  if n < 32 then put w (0x20 + n) 1
  else if n < 256 then (put w 0x09 1; put w n 1)
  else (put w 0x0A 1; put w n 4);
  Buffer.add_string w.out s;
  words w (2 + n / 4) (2 + n / 8)

(* (OCaml's sizes: a custom block has a word more, its operations) *)
let write_int64 (w : writer) (n : int64) : unit =
  let b = Bytes.create 8 in
  Bytes.set_int64_be b 0 n;
  Buffer.add_string w.out "\x19_j\000";
  Buffer.add_bytes w.out b;
  words w 4 3

let write_int32 (w : writer) (n : int32) : unit =
  let b = Bytes.create 4 in
  Bytes.set_int32_be b 0 n;
  Buffer.add_string w.out "\x19_i\000";
  Buffer.add_bytes w.out b;
  words w 3 3

(* v written whole: true. Or, a block of fields, all but its last one:
 * false, and [write] goes on with it in a loop, not a call (mini-ml
 * makes a call of a tail call: a long list would be a deep stack). *)
let rec written (w : writer) (v : Obj.t) : bool =
  if Obj.is_int v then (write_int w (Obj.obj v); true)
  else if Obj.size v = 0 then (put w (0x80 + Obj.tag v) 1; true)
  else
    match number w.seen v with
    | Some n -> write_shared w (w.seen.count - n); true
    | None ->
        let tag = Obj.tag v in
        if tag = Obj.string_tag then (write_string w (Obj.obj v); true)
        else if tag = Obj.double_tag then begin
          put w 0x0C 1;
          Buffer.add_int64_le w.out (Int64.bits_of_float (Obj.obj v));
          words w 3 2;
          true
        end
        else if tag = int64_tag then (write_int64 w (Obj.obj v); true)
        else if tag = int32_tag then (write_int32 w (Obj.obj v); true)
        else if tag = closure_tag then invalid_arg "output_value: functional value"
        else begin
          let n = Obj.size v in
          if tag < 16 && n < 8 then put w (0x80 + tag + n * 16) 1
          else (put w 0x08 1; put w (n * 1024 + tag) 4);
          words w (1 + n) (1 + n);
          for i = 0 to n - 2 do
            write w (Obj.field v i)
          done;
          false
        end

and write (w : writer) (v : Obj.t) : unit =
  let v = ref v in
  while not (written w !v) do
    v := Obj.field !v (Obj.size !v - 1)
  done

let to_string (v : 'a) (_flags : extern_flags list) : string =
  let seen = { blocks = Array.make 64 (Obj.repr 0); numbers = Array.make 64 0; count = 0; epoch = collections () } in
  let w = { out = Buffer.create 4096; seen; words32 = 0; words64 = 0 } in
  Buffer.add_string w.out magic;
  put w 0 (header_size - 4);
  write w (Obj.repr v);
  (* the header's numbers, now that they are known *)
  let s = Buffer.to_bytes w.out in
  List.iteri (fun i n -> Bytes.set_int32_be s (4 * (i + 1)) (Int32.of_int n))
    [ Bytes.length s - header_size; seen.count; w.words32; w.words64 ];
  Bytes.unsafe_to_string s

let to_channel (chan : out_channel) (v : 'a) (flags : extern_flags list) : unit =
  output_string chan (to_string v flags)

let to_buffer (buff : bytes) (ofs : int) (len : int) (v : 'a) (flags : extern_flags list) : int =
  if ofs < 0 || len < 0 || ofs + len > Bytes.length buff
  then invalid_arg "Marshal.to_buffer: substring out of bounds";
  let s = to_string v flags in
  if String.length s > len then failwith "Marshal.to_buffer: buffer overflow";
  String.blit s 0 buff ofs (String.length s);
  String.length s

(*****************************************************************************)
(* Reading *)
(*****************************************************************************)

type reader = {
  src : string;
  mutable pos : int;
  (* the blocks read, by their number *)
  blocks : Obj.t array;
  mutable count : int;
  (* the block [item] last returned has its last field still to read *)
  mutable unfinished : bool;
}

let byte (r : reader) : int =
  let c = Char.code r.src.[r.pos] in
  r.pos <- r.pos + 1;
  c

(* the next bytes as a number, the high one first, after those in high *)
let rec after (r : reader) (high : int) (bytes : int) : int =
  if bytes = 0 then high else after r ((high lsl 8) lor byte r) (bytes - 1)

let unsigned (r : reader) (bytes : int) : int = after r 0 bytes

let signed (r : reader) (bytes : int) : int =
  let high = byte r in
  after r (if high >= 128 then high - 256 else high) (bytes - 1)

let numbered (r : reader) (v : Obj.t) : Obj.t =
  r.blocks.(r.count) <- v;
  r.count <- r.count + 1;
  v

let shared (r : reader) (ago : int) : Obj.t =
  r.blocks.(r.count - ago)

let read_string (r : reader) (n : int) : Obj.t =
  let s = String.sub r.src r.pos n in
  r.pos <- r.pos + n;
  numbered r (Obj.repr s)

let read_float (r : reader) (bits : int64) : Obj.t =
  r.pos <- r.pos + 8;
  numbered r (Obj.repr (Int64.float_of_bits bits))

(* "_j" an int64, "_i" an int32; before its bytes, 12 of sizes if the
 * code says so (0x18) *)
let read_custom (r : reader) (sizes : int) : Obj.t =
  let name = String.sub r.src r.pos 3 in
  let data = r.pos + 3 + sizes in
  if name = "_j\000" then begin
    r.pos <- data + 8;
    numbered r (Obj.repr (String.get_int64_be r.src data))
  end
  else if name = "_i\000" then begin
    r.pos <- data + 4;
    numbered r (Obj.repr (String.get_int32_be r.src data))
  end
  else failwith "input_value: unknown custom block"

(* the next value, whole. Or, a block of fields, with all but its last
 * one, and [r.unfinished]: [read] goes on with it in a loop, as
 * [write] does. *)
let rec item (r : reader) : Obj.t =
  r.unfinished <- false;
  let code = byte r in
  if code >= 0x80 then read_block r (code land 15) ((code lsr 4) land 7)
  else if code >= 0x40 then Obj.repr (code land 63)
  else if code >= 0x20 then read_string r (code land 31)
  else
    match code with
    | 0x00 -> Obj.repr (signed r 1)
    | 0x01 -> Obj.repr (signed r 2)
    | 0x02 -> Obj.repr (signed r 4)
    | 0x03 ->
        if Sys.word_size = 32 then failwith "input_value: integer too large";
        Obj.repr (signed r 8)
    | 0x04 -> shared r (unsigned r 1)
    | 0x05 -> shared r (unsigned r 2)
    | 0x06 -> shared r (unsigned r 4)
    | 0x08 ->
        let header = unsigned r 4 in
        read_block r (header land 255) (header lsr 10)
    | 0x09 -> read_string r (unsigned r 1)
    | 0x0A -> read_string r (unsigned r 4)
    | 0x0B -> read_float r (String.get_int64_be r.src r.pos)
    | 0x0C -> read_float r (String.get_int64_le r.src r.pos)
    | 0x12 | 0x19 -> read_custom r 0
    | 0x18 -> read_custom r 12
    | _ -> failwith "input_value: ill-formed message"

and read_block (r : reader) (tag : int) (n : int) : Obj.t =
  if n = 0 then Obj.repr [||]
  else begin
    let b = numbered r (Obj.new_block tag n) in
    for i = 0 to n - 2 do
      Obj.set_field b i (read r)
    done;
    r.unfinished <- true;
    b
  end

and read (r : reader) : Obj.t =
  let v = item r in
  let b = ref v in
  while r.unfinished do
    let last = item r in
    Obj.set_field !b (Obj.size !b - 1) last;
    b := last
  done;
  v

let data_size (buff : string) (ofs : int) : int =
  if ofs < 0 || ofs + header_size > String.length buff
  then invalid_arg "Marshal.data_size";
  if String.sub buff ofs 4 <> magic then failwith "Marshal.data_size: bad object";
  header_int buff ofs 1

let total_size (buff : string) (ofs : int) : int = header_size + data_size buff ofs

let from_string (buff : string) (ofs : int) : 'a =
  if ofs < 0 || ofs + header_size > String.length buff
  then invalid_arg "Marshal.from_string";
  if String.sub buff ofs 4 <> magic then failwith "input_value: bad object";
  if ofs + header_size + header_int buff ofs 1 > String.length buff
  then invalid_arg "Marshal.from_string";
  let blocks = Array.make (header_int buff ofs 2 + 1) (Obj.repr 0) in
  Obj.obj (read { src = buff; pos = ofs + header_size; blocks; count = 0; unfinished = false })

let from_channel (chan : in_channel) : 'a =
  let header = really_input_string chan header_size in
  let len = header_int header 0 1 in
  let s = Bytes.create (header_size + len) in
  String.blit header 0 s 0 header_size;
  (try really_input chan s header_size len
   with End_of_file -> failwith "input_value: truncated object");
  from_string (Bytes.unsafe_to_string s) 0

(* ix: OCaml's later names, for bytes: the same block (to_string's is
 * no one else's; from_bytes reads only) *)
let to_bytes (v : 'a) (flags : extern_flags list) : bytes = Bytes.unsafe_of_string (to_string v flags)
let from_bytes (buff : bytes) (ofs : int) : 'a = from_string (Bytes.unsafe_to_string buff) ofs
