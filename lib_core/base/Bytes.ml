(* partial port of 4.02 bytes.ml just enough to compile some of ocaml-light with
 * dune and a recent OCaml (as well as xix)
 *)
(* ix: bytes are mini-ml's own type now, not string's other name (old:
 * type t = string): what is written is bytes, and a string is not, as
 * OCaml's since 4.06. The same block for both: unsafe_to_string and
 * unsafe_of_string are the identity, for bytes that are no longer
 * written (or a string no one else has); to_string and of_string copy.
 * What only reads is String's, on the bytes as a string (uts). *)
type t = bytes

external unsafe_to_string : bytes -> string = "%identity"
external unsafe_of_string : string -> bytes = "%identity"
external uts : bytes -> string = "%identity"

(* (the primitive, as String's: an instruction where it is asked, not a
 * call; old: let length x = String.length x) *)
external length : bytes -> int = "%string_length"

(* old: let create x = String.create x *)
external create : int -> bytes = "create_string"

let empty = create 0

let sub x n1 n2 = unsafe_of_string (String.sub (uts x) n1 n2)

let sub_string x n1 n2 = String.sub (uts x) n1 n2

(* a copy, as OCaml's: the string is not to change with the bytes *)
let to_string x = String.copy (uts x)

let of_string x = unsafe_of_string (String.copy x)

(* (the primitives too, as unsafe_get and unsafe_set below: the kernels'
 * strings that are written are bytes now, mini-9pi's pixels among them,
 * read and set where s.[i] and String.set were;
 * old: let get x n = String.get x n
 *      let set s x c = String.set s x c) *)
external get : bytes -> int -> char = "%string_safe_get"

external set : bytes -> int -> char -> unit = "%string_safe_set"

let index_from s n c = String.index_from (uts s) n c

(* The primitives themselves, as String's are: not functions that call
 * them. A program that sets pixels calls these for every byte
 * (lib_graphics/software's Framebuffer): as functions, a million pixels
 * took 0.56 s where ocamlopt's code takes 0.01
 * (docs/plans/plan_playground_speed.md, M1).
 * old: let unsafe_get x n = String.unsafe_get x n
 *      let unsafe_set = String.unsafe_set *)
external unsafe_get : bytes -> int -> char = "%string_unsafe_get"
external unsafe_set : bytes -> int -> char -> unit = "%string_unsafe_set"

let blit_string = String.blit

let blit src srcoff dst dstoff len =
  String.blit (uts src) srcoff dst dstoff len

let unsafe_blit src srcoff dst dstoff len =
  String.unsafe_blit (uts src) srcoff dst dstoff len

let unsafe_blit_string = String.unsafe_blit

(* (was String's, ocaml-light's) *)
external unsafe_fill : bytes -> int -> int -> char -> unit = "fill_string" "noalloc"
let fill s ofs len c =
  if ofs < 0 || len < 0 || ofs + len > length s
  then invalid_arg "Bytes.fill"
  else unsafe_fill s ofs len c

let make n c = unsafe_of_string (String.make n c)

let equal (a : bytes) (b : bytes) = a = b

let compare (a : bytes) (b : bytes) = compare a b

(* ix: OCaml's later functions, those ix's programs use *)

let copy b = of_string (uts b)
let cat a b = unsafe_of_string (uts a ^ uts b)
let concat sep l = unsafe_of_string (String.concat (uts sep) (List.map uts l))
let iteri f b = String.iteri f (uts b)
let index_from_opt b i c = String.index_from_opt (uts b) i c

(* the binary fields: the readers are String's *)
let get_uint8 s i = Char.code (get s i)
let get_int8 s i = let n = get_uint8 s i in if n >= 128 then n - 256 else n
let get_uint16_le s i = String.get_uint16_le (uts s) i
let get_uint16_be s i = String.get_uint16_be (uts s) i
let get_int16_be s i = let n = get_uint16_be s i in if n >= 32768 then n - 65536 else n
let get_int32_le s i = String.get_int32_le (uts s) i
let get_int32_be s i = String.get_int32_be (uts s) i
let get_int64_le s i = String.get_int64_le (uts s) i
let get_int64_be s i = String.get_int64_be (uts s) i

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
