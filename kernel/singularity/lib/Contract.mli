(* mini-singularity: a channel's contract, as a value (decision 4 of
 * plan_system_singularity.md): its messages, each with who sends it
 * and what it carries, and its states, each with the messages it
 * allows and the state after. The channel's maker gives it to the
 * kernel, which keeps the channel's state and refuses a message the
 * state does not allow. Sing#'s compiler proves that no such message
 * is sent; here it is found when it is.
 *
 * Linked in the kernel and in every program: the one description. A
 * contract's own module (contracts/) is written over it. *)

(* a channel's two ends: the importing (the client's) and the exporting
 * (the server's) *)
type side = Imp | Exp

(* besides its integer *)
type carries =
  | Nothing
  | Block                       (* of the exchange heap *)
  | Endpoint of string * side   (* of a channel of that contract, that end of it *)

type message = {
  label : string;
  from : side;
  carries : carries;
}

type t = {
  name : string;
  messages : message array;             (* a message's tag is its place *)
  states : (int * int) list array;      (* a state's: a tag, the state after; 0 the start *)
}

(* a message, a contract: for a contract's module, which has no need of
 * the fields' names *)
val message : string -> side -> carries -> message
val make : string -> message array -> (int * int) list array -> t

(* as bytes, for the kernel's call, and back: None for what is no contract *)
val encode : t -> string
val decode : string -> t option
