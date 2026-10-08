(* partial port of 4.02 bytes.ml just enough to compile some of ocaml-light with
 * dune and a recent OCaml (as well as xix)
 *)
type t = string

let empty = ""

let sub x n1 n2 = String.sub x n1 n2

let sub_string x n1 n2 = String.sub x n1 n2

(* (the primitive, as String's: an instruction where it is asked, not a
 * call; old: let length x = String.length x) *)
external length : string -> int = "%string_length"

let create x = String.create x

(* a copy, as OCaml's: bytes are strings here, and the string is not to
 * change with the bytes; unsafe_to_string and unsafe_of_string don't copy *)
let to_string x = String.copy x

let of_string x = String.copy x

(* (the primitives too, as unsafe_get and unsafe_set below: the kernels'
 * strings that are written are bytes now, mini-9pi's pixels among them,
 * read and set where s.[i] and String.set were;
 * old: let get x n = String.get x n
 *      let set s x c = String.set s x c) *)
external get : string -> int -> char = "%string_safe_get"

external set : string -> int -> char -> unit = "%string_safe_set"

let index_from s n c = String.index_from s n c

(* The primitives themselves, as String's are: not functions that call
 * them. A program that sets pixels calls these for every byte
 * (lib_graphics/software's Framebuffer): as functions, a million pixels
 * took 0.56 s where ocamlopt's code takes 0.01
 * (docs/plans/plan_playground_speed.md, M1).
 * old: let unsafe_get x n = String.unsafe_get x n
 *      let unsafe_set = String.unsafe_set *)
external unsafe_get : string -> int -> char = "%string_unsafe_get"
external unsafe_set : string -> int -> char -> unit = "%string_unsafe_set"

let unsafe_to_string x = x

let unsafe_of_string x = x

let blit src srcoff dst dstoff len =
  String.blit src srcoff dst dstoff len

let unsafe_blit src srcoff dst dstoff len =
  String.unsafe_blit src srcoff dst dstoff len

let blit_string = blit

let fill s start len c = String.fill s start len c


let make = String.make

let equal = ( = )

let compare = compare

(* ix: OCaml's later functions, those ix's programs use *)

let copy = String.copy
let cat a b = a ^ b
let concat = String.concat
let iteri = String.iteri
let index_from_opt = String.index_from_opt

(* the binary fields: the readers are String's *)
let get_uint8 s i = Char.code (get s i)
let get_int8 s i = let n = get_uint8 s i in if n >= 128 then n - 256 else n
let get_uint16_le = String.get_uint16_le
let get_uint16_be = String.get_uint16_be
let get_int16_be s i = let n = get_uint16_be s i in if n >= 32768 then n - 65536 else n
let get_int32_le = String.get_int32_le
let get_int32_be = String.get_int32_be
let get_int64_le = String.get_int64_le
let get_int64_be = String.get_int64_be

let set_uint8 s i n = set s i (Char.unsafe_chr (n land 0xff))
let set_uint16_le s i n = set_uint8 s i n; set_uint8 s (i + 1) (n lsr 8)
let set_uint16_be s i n = set_uint8 s i (n lsr 8); set_uint8 s (i + 1) n

(* a 32-bit integer's two halves *)
let low16 n = Int32.to_int n land 0xffff
let high16 n = Int32.to_int (Int32.shift_right_logical n 16) land 0xffff
let set_int32_le s i n = set_uint16_le s i (low16 n); set_uint16_le s (i + 2) (high16 n)
let set_int32_be s i n = set_uint16_be s i (high16 n); set_uint16_be s (i + 2) (low16 n)

let high32 n = Int64.to_int32 (Int64.shift_right_logical n 32)
let set_int64_le s i n = set_int32_le s i (Int64.to_int32 n); set_int32_le s (i + 4) (high32 n)
let set_int64_be s i n = set_int32_be s i (high32 n); set_int32_be s (i + 4) (Int64.to_int32 n)
