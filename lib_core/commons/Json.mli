(* JSON: objects, arrays, strings, integers, booleans, null; no floats
 * (mini-qemu's QMP, the first user, has none).
 *
 *   let j = of_text {|{"execute": "send-key", "arguments": {"keys": []}}|}
 *   member "execute" j = String "send-key"
 *   to_text j = {|{"execute":"send-key","arguments":{"keys":[]}}|}
 *
 * A value is a tree, and the type below is the whole grammar: the
 * parser is a function a case, by recursive descent, and the printer
 * a match. An object keeps its fields as a list, in the order read:
 * [member] walks it, which is right for a message of five fields and
 * would not be for a table.
 *
 * cs-history:
 * JSON is the notation of JavaScript's own object and array
 * literals, which Douglas Crockford named and wrote down in the
 * early 2000s so that a page and its server could exchange data
 * with no parser to write on the page's side. It replaced XML there
 * by having less: no attributes, no namespaces, no schema, six
 * kinds of value.
 *
 * References: RFC 8259 (2017), the grammar on a few pages; QEMU's
 * QMP specification for the messages Qmp sends. The browser's
 * JavaScript engine has its own JSON.parse, over its own values
 * (Js_json, where the history is longer). *)

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
