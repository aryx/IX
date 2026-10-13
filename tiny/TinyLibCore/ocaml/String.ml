(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* String operations *)

external length : string -> int = "%string_length"
external get : string -> int -> char = "%string_safe_get"
external unsafe_get : string -> int -> char = "%string_unsafe_get"

(* ix: a string is not written, as OCaml's since 4.06: what is written
 * is bytes (mini-ml's type, Bytes its module, after this one). So set,
 * create and fill are Bytes' only, and here a string is made as bytes
 * and given whole (bts: the same block). The five below are this
 * file's own.
 * old: external set : string -> int -> char -> unit = "%string_safe_set"
 *      external create: int -> string = "create_string"
 *      and unsafe_set, unsafe_blit, unsafe_fill over strings *)
external create: int -> bytes = "create_string"
external unsafe_set : bytes -> int -> char -> unit = "%string_unsafe_set"
external unsafe_blit : string -> int -> bytes -> int -> int -> unit
                     = "blit_string" "noalloc"
external unsafe_fill : bytes -> int -> int -> char -> unit
                     = "fill_string" "noalloc"
external bts : bytes -> string = "%identity"
external bytes_length : bytes -> int = "%string_length"

let make n c =
  let s = create n in
  unsafe_fill s 0 n c;
  bts s

let copy s =
  let len = length s in
  let r = create len in
  unsafe_blit s 0 r 0 len;
  bts r

let sub s ofs len =
  if ofs < 0 or len < 0 or ofs + len > length s
  then invalid_arg "String.sub"
  else begin
    let r = create len in
    unsafe_blit s ofs r 0 len;
    bts r
  end

let blit s1 ofs1 s2 ofs2 len =
  if len < 0 or ofs1 < 0 or ofs1 + len > length s1
             or ofs2 < 0 or ofs2 + len > bytes_length s2
  then invalid_arg "String.blit"
  else unsafe_blit s1 ofs1 s2 ofs2 len

let concat sep l =
  match l with
    [] -> ""
  | hd :: tl ->
      let num = ref 0 and len = ref 0 in
      List.iter (fun s -> incr num; len := !len + length s) l;
      let r = create (!len + length sep * (!num - 1)) in
      unsafe_blit hd 0 r 0 (length hd);
      let pos = ref(length hd) in
      List.iter
        (fun s ->
          unsafe_blit sep 0 r !pos (length sep);
          pos := !pos + length sep;
          unsafe_blit s 0 r !pos (length s);
          pos := !pos + length s)
        tl;
      bts r

external is_printable: char -> bool = "is_printable"
external char_code: char -> int = "%identity"
external char_chr: int -> char = "%identity"

let is_space = function
  | ' ' | '\012' | '\n' | '\r' | '\t' -> true
  | _ -> false

let trim s =
  let len = length s in
  let i = ref 0 in
  while !i < len && is_space (unsafe_get s !i) do
    incr i
  done;
  let j = ref (len - 1) in
  while !j >= !i && is_space (unsafe_get s !j) do
    decr j
  done;
  if !i = 0 && !j = len - 1 then
    s
  else if !j >= !i then
    sub s !i (!j - !i + 1)
  else
    ""

let escaped s =
  let n = ref 0 in
    for i = 0 to length s - 1 do
      n := !n +
        (match unsafe_get s i with
           '"' | '\\' | '\n' | '\t' | '\r' | '\b' -> 2
          | c -> if is_printable c then 1 else 4)
    done;
    if !n = length s then s else begin
      let s' = create !n in
        n := 0;
        for i = 0 to length s - 1 do
          begin
            match unsafe_get s i with
              ('"' | '\\') as c ->
                unsafe_set s' !n '\\'; incr n; unsafe_set s' !n c
            | '\n' ->
                unsafe_set s' !n '\\'; incr n; unsafe_set s' !n 'n'
            | '\t' ->
                unsafe_set s' !n '\\'; incr n; unsafe_set s' !n 't'
            (* ix: as OCaml 4.14's (ocaml-light's wrote \013 and \008) *)
            | '\r' ->
                unsafe_set s' !n '\\'; incr n; unsafe_set s' !n 'r'
            | '\b' ->
                unsafe_set s' !n '\\'; incr n; unsafe_set s' !n 'b'
            | c ->
                if is_printable c then
                  unsafe_set s' !n c
                else begin
                  let a = char_code c in
                  unsafe_set s' !n '\\';
                  incr n;
                  unsafe_set s' !n (char_chr (48 + a / 100));
                  incr n;
                  unsafe_set s' !n (char_chr (48 + (a / 10) mod 10));
                  incr n;
                  unsafe_set s' !n (char_chr (48 + a mod 10))
                end
          end;
          incr n
        done;
        bts s'
      end

let map f s =
  let l = length s in
  if l = 0 then s else begin
    let r = create l in
    for i = 0 to l - 1 do unsafe_set r i (f(unsafe_get s i)) done;
    bts r
  end

let uppercase s = map Char.uppercase s
let lowercase s = map Char.lowercase s

let uppercase_ascii s = uppercase s
let lowercase_ascii s = lowercase s

let apply1 f s =
  if length s = 0 then s else begin
    let r = create (length s) in
    unsafe_blit s 0 r 0 (length s);
    unsafe_set r 0 (f(unsafe_get s 0));
    bts r
  end

let rec index_rec s i c =
  if i >= length s then raise Not_found
  else if unsafe_get s i = c then i
  else index_rec s (i+1) c

let index s c = index_rec s 0 c

let index_from s i c =
  if i < 0 || i >= length s
  then invalid_arg "String.index_from"
  else index_rec s i c

let rec rindex_rec s i c =
  if i < 0 then raise Not_found
  else if unsafe_get s i = c then i
  else rindex_rec s (i-1) c

let rindex s c = rindex_rec s (length s - 1) c

type t = string

let compare (x: t) (y: t) = compare x y

(* external equal : string -> string -> bool = "caml_string_equal" [@@noalloc] *)
let equal x y = compare x y = 0

(** backported from 4.13.0 *)

(* duplicated in bytes.ml *)
let starts_with ~prefix s =
  let len_s = length s
  and len_pre = length prefix in
  let rec aux i =
    if i = len_pre then true
    else if unsafe_get s i <> unsafe_get prefix i then false
    else aux (i + 1)
  in len_s >= len_pre && aux 0

(* duplicated in bytes.ml *)
let ends_with ~suffix s =
  let len_s = length s
  and len_suf = length suffix in
  let diff = len_s - len_suf in
  let rec aux i =
    if i = len_suf then true
    else if unsafe_get s (diff + i) <> unsafe_get suffix i then false
    else aux (i + 1)
  in diff >= 0 && aux 0

let split_on_char sep s =
  let r = ref [] in
  let j = ref (length s) in
  for i = length s - 1 downto 0 do
    if unsafe_get s i = sep then begin
      r := sub s (i + 1) (!j - i - 1) :: !r;
      j := i
    end
  done;
  sub s 0 !j :: !r

(* ix: OCaml's later functions, those ix's programs use *)

let contains s c = try ignore (index_rec s 0 c); true with Not_found -> false
let index_opt s c = try Some (index_rec s 0 c) with Not_found -> None
let rindex_opt s c = try Some (rindex_rec s (length s - 1) c) with Not_found -> None
let rindex_from_opt s i c =
  if i < -1 || i >= length s then invalid_arg "String.rindex_from_opt / Bytes.rindex_from_opt"
  else try Some (rindex_rec s i c) with Not_found -> None

let index_from_opt s i c =
  if i < 0 || i > length s then invalid_arg "String.index_from_opt / Bytes.index_from_opt"
  else try Some (index_rec s i c) with Not_found -> None

let iter f s = for i = 0 to length s - 1 do f (unsafe_get s i) done
let iteri f s = for i = 0 to length s - 1 do f i (unsafe_get s i) done
let for_all p s = let rec go i = i = length s || (p (unsafe_get s i) && go (i + 1)) in go 0
let exists p s = let rec go i = i < length s && (p (unsafe_get s i) || go (i + 1)) in go 0

let init n f =
  let s = create n in
  for i = 0 to n - 1 do unsafe_set s i (f i) done;
  bts s

(* from bytes, each read by get: its bounds checked *)
let byte s i = Char.code (get s i)
let get_uint16_le s i = byte s i lor (byte s (i + 1) lsl 8)
let get_uint16_be s i = (byte s i lsl 8) lor byte s (i + 1)

let get_int32_le s i =
  Int32.logor (Int32.of_int (get_uint16_le s i)) (Int32.shift_left (Int32.of_int (get_uint16_le s (i + 2))) 16)

let get_int32_be s i =
  Int32.logor (Int32.shift_left (Int32.of_int (get_uint16_be s i)) 16) (Int32.of_int (get_uint16_be s (i + 2)))

(* the low half without its sign *)
let low32 n = Int64.logand (Int64.of_int32 n) 0xffffffffL
let get_int64_le s i = Int64.logor (low32 (get_int32_le s i)) (Int64.shift_left (Int64.of_int32 (get_int32_le s (i + 4))) 32)
let get_int64_be s i = Int64.logor (Int64.shift_left (Int64.of_int32 (get_int32_be s i)) 32) (low32 (get_int32_be s (i + 4)))
