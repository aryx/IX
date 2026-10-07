(* mini-singml: a contract's declaration read (kernel/singularity's
 * plan_system_singularity.md, stage 4). A declaration is a file in
 * OCaml's syntax, read by mini-ml's own parser; what it means is here.
 *
 *   type request = Ping of int | Text of Sip.block * int
 *   type reply = Ready | Pong of int | Thanks
 *
 *   let rec start = send Ready; serve
 *   and serve = function
 *     | Ping _ -> send Pong; serve
 *     | Text _ -> send Thanks; serve
 *
 * The messages are the constructors of its variant types. The states
 * are the bindings of its one let rec, the first the start, each said
 * from the exporting end (the server's), as Sing#'s:
 *   function | M _ -> s | ...   one of these messages is received
 *                               (sent by the importing end), then s
 *   send M; s                   M is sent (to the importing end), then s
 *   s1 || s2                    as s1 or as s2 (each a send)
 *   name                        that state
 *   ()                          nothing more
 * A message is so the importing end's to send, or the exporting end's,
 * by where it is; a type's messages are all one end's.
 *
 * A message's arguments: an int at most, and a Sip.block or another
 * contract's end (Pong.imp, Pong.exp) at most. *)

(* what a message carries besides its integer *)
type carried =
  | Nothing
  | Block
  | End of string * bool                (* a contract's name; its importing end *)

type message = {
  label : string;
  from_imp : bool;                      (* sent by the importing end *)
  args : string list;                   (* its arguments' types, as written *)
  value : int option;                   (* which argument is its integer *)
  carried : carried;
  what : int option;                    (* which argument is carried *)
}

type t = {
  name : string;
  (* the types, as declared: a name, its messages' tags, the end that sends them *)
  types : (string * int list * bool) list;
  messages : message array;             (* a message's tag is its place *)
  states : (string * (int * int) list) array;   (* a name; a tag, the state after *)
}

(* the line, the message *)
exception Error of int * string

(* [read name tree]: the contract of that name a file's tree declares *)
val read : string -> Ast.structure -> t
