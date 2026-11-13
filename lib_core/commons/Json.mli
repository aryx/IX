(* JSON: objects, arrays, strings, numbers, booleans and null. It is what
 * mini-qemu's QMP speaks (QMP was the first user), and what a forecast's
 * temperatures come in (mini-maps).
 *
 *   let j = of_text {|{"execute": "send-key", "arguments": {"keys": []}}|}
 *   member "execute" j = String "send-key"
 *   to_text j = {|{"execute":"send-key","arguments":{"keys":[]}}|}
 *
 * A value is a tree, and the type below is the whole grammar. The
 * parser works by recursive descent, with one case for each kind of
 * value, and the printer is one match. An object keeps its fields as
 * a list, in the order they were read, and [member] walks that list.
 * This is right for a message of five fields, but would not be for a
 * table.
 *
 * cs-history:
 * JSON is the notation of JavaScript's own object and array
 * literals, which Douglas Crockford named and wrote down in the
 * early 2000s so that a page and its server could exchange data
 * with no parser to write on the page's side. It replaced XML there
 * by having less: no attributes, no namespaces, no schema, six
 * kinds of value.
 *
 * References: RFC 8259 (2017), which gives the grammar in a few pages;
 * QEMU's QMP specification, for the messages Qmp sends. The browser's
 * JavaScript engine has its own JSON.parse, over its own values
 * (Js_json, where the history is longer). *)

type t = Null | Bool of bool | Int of int | Float of float | String of string | List of t list | Assoc of (string * t) list

exception Error of string

(* The value as one line of text, as QMP writes its messages *)
val to_text : t -> string

(* Error if the text isn't JSON, or has something after the value *)
val of_text : string -> t

(* The same, for a long text: [turn ()] is called at each value. This is
 * for mini-ml's threads: a thread must give up its turn, or the others
 * wait until all of the text is parsed. *)
val of_text_turning : (unit -> unit) -> string -> t

(* An object's field, or Null when it is absent; Error if the value is
 * not an object *)
val member : string -> t -> t

(* The value inside; Error if it is of another kind *)
val string : t -> string
val int : t -> int

(* A number, which may be an Int too: 3 is as good a temperature as 3.5 *)
val float : t -> float
val bool : t -> bool
val list : t -> t list
