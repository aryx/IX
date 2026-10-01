(* JSON: objects, arrays, strings, integers, booleans, null; no floats
 * (mini-qemu's QMP, the first user, has none).
 *
 *   of_string {|{"execute": "send-key", "arguments": {"keys": []}}|}
 *   member "execute" j = String "send-key" *)

type t = Null | Bool of bool | Int of int | String of string | List of t list | Assoc of (string * t) list

exception Error of string

(* one line of it, as QMP writes them *)
val to_text : t -> string

(* Error if it isn't JSON, or has something after *)
val of_text : string -> t

(* an object's field, Null when absent; Error for a non-object *)
val member : string -> t -> t

(* the value, Error if it is of another kind *)
val string : t -> string
val int : t -> int
val bool : t -> bool
val list : t -> t list
